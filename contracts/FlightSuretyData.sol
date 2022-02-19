pragma solidity ^0.4.25;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

contract FlightSuretyData {
    using SafeMath for uint256;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    address private contractOwner;                                      // Account used to deploy contract
    bool private operational = true;                                    // Blocks all state changes throughout the contract if false

    // airline
    struct Airline {
        string name;
        bool isRegistered;
        bool registrationFee;
    }

    mapping(address => Airline) airlines;
    uint256 public totalRegisteredAirlines;
    mapping(address => bool) private authorizedCaller;

    struct Flight {
        uint statusCode;
        string flightCode;
        string origin;
        string destination;
        uint256 departureTime;
        uint ticketFee;
        address airlineAddress;
        mapping(address => bool) flightBookings;
        mapping(address => uint) flightInsurances;
    }     
    mapping(bytes32 => Flight) public flights;                            
    bytes32[] public flightKeys;
    uint public totalFlightKeys = 0;
    address[] internal customers;
    mapping(address => uint) public insureeCredit;

    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/


    /**
    * @dev Constructor
    *      The deploying account becomes contractOwner
    */
    constructor
                                (
                                    address genesisAirline
                                ) 
                                public 
    {
        authorizedCaller[msg.sender] = true;
        contractOwner = msg.sender;
        airlines[msg.sender] = Airline({
                                     name: "Genesis Airline",
                                     isRegistered: true,
                                     registrationFee: true
        });
        airlines[genesisAirline].isRegistered = true;
        totalRegisteredAirlines = 1;
    }
    
    /********************************************************************************************/
    /*                                       Events                                 */
    /********************************************************************************************/

    event newAirlineRegistered(address newAirline,address airlineReferral);     // register a new event
    
    event receivedRegistrationFee(address fundAddress);

    event gotTicket(bytes32 flightKey,address passengerAddress); 

    event boughtInsurance(bytes32 flightKey,address customerAddress, uint amount); 

    event creditInsurance(uint payment, address customer); 

    event insurancePaid(uint payment, address customer);
    /********************************************************************************************/
    /*                                       FUNCTION MODIFIERS                                 */
    /********************************************************************************************/

    // Modifiers help avoid duplication of code. They are typically used to validate something
    // before a function is allowed to be executed.

    /**
    * @dev Modifier that requires the "operational" boolean variable to be "true"
    *      This is used on all state changing functions to pause the contract in 
    *      the event there is an issue that needs to be fixed
    */
    modifier requireIsOperational() 
    {
        require(operational, "Contract is currently not operational");
        _;  // All modifiers require an "_" which indicates where the function body will be added
    }

    /**
    * This is used to check when the caller is authorized
    */
    modifier requireIsCallerAuthorized()
    {
        require(authorizedCaller[msg.sender] == true, "Not authorized caller");
        _;
    }

    /**
    * @dev Modifier that requires the "ContractOwner" account to be the function caller
    */
    modifier requireContractOwner()
    {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }

    modifier requireIsFlight(bytes32 flightKey)
    {
        require(flights[flightKey].ticketFee > 0, "Flight does not exist");
        _;
    }

    modifier requiredNoProccessPaymentInsuree(bytes32 flightKey) {
        require(flights[flightKey].statusCode != 20, "No insurance is returned except flight is delayed by airline");
        _;
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    /**
    * @dev Get operating status of contract
    *
    * @return A bool that is the current operating status
    */      
    function isOperational() 
                            public 
                            view 
                            returns(bool) 
    {
        return operational;
    }


    /**
    * @dev Sets contract operations on/off
    *
    * When operational mode is disabled, all write transactions except for this one will fail
    */    
    function setOperatingStatus
                            (
                                bool mode
                            ) 
                            external
    {
        require(authorizedCaller[msg.sender] == true, "Caller is not authorized");
        operational = mode;
    }

    function authorizeCaller
                        (
                            address callerAddress
                        )
                        external
                        requireContractOwner
    {
        authorizedCaller[callerAddress] = true;
    }

    function deauthorizeCaller
                        (
                            address callerAddress
                        )
                        external
                        requireContractOwner
    {
        delete authorizedCaller[callerAddress];
    }

    function isAuthorizedCaller 
                        (
                            address caller
                        ) 
                        public 
                        view  
                        returns (bool)
                        {
        return authorizedCaller[caller]; 
    }

    function isAirline(
                    address addressAirline
                        )
                        external
                        view
                        returns (bool)
                        {                    
        return airlines[addressAirline].isRegistered;                                                   
    }

    function paidRegistration(
                               address airlineAddress
                               ) 
                               external
                               view 
                              returns (bool registrationFee)
    {
        registrationFee = airlines[airlineAddress].registrationFee;
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

   /**
    * @dev Add an airline to the registration queue
    *      Can only be called from FlightSuretyApp contract
    *
    */   
    function registerAirline
                            (  
                                string name,
                                address newAirline,
                                address airlineReferral 
                            )
                            external
                            requireIsOperational
    {
        require(!airlines[newAirline].isRegistered, "Airline is registered alredy");
        require(airlines[airlineReferral].isRegistered, "Referral Airline is not yet registered.");

        airlines[newAirline] = Airline({
                                     name: name,
                                     isRegistered: true,
                                     registrationFee: false
        });
        totalRegisteredAirlines = totalRegisteredAirlines.add(1);

        emit newAirlineRegistered(newAirline,airlineReferral);
    }

    function registerFlight
                        (
                            uint statusCode,
                            string flightCode,
                            string origin,
                            string destination,
                            uint256 departureTime,
                            uint ticketFee,
                            address airlineAddress
                        )
                        external
                        requireIsOperational
    {
        require(departureTime > now, "Flight time must be later");

        Flight memory flight = Flight(
          statusCode,
          flightCode,
          origin,
          destination,
          departureTime,
          ticketFee,
          airlineAddress
        );

        bytes32 flightKey = getFlightKey
                           (
                            airlineAddress,
                            flightCode,
                            departureTime
                           );

        flights[flightKey] = flight;

        totalFlightKeys = flightKeys.push(flightKey).sub(1);

    }

    /**
    * @dev Buy flight ticket
    *
    */
    function getFlightTicket
                            (
                                    bytes32 flightKey, 
                                    address customerAddress                             
                            )
                            external
                            requireIsOperational
                            requireIsFlight(flightKey)
                            payable
    {
        Flight storage flight = flights[flightKey];    
        flight.flightBookings[customerAddress] = true;          
        emit gotTicket(flightKey,customerAddress);                

    }

   /**
    * @dev Buy insurance for a flight
    *
    */   
    function buyFligthAndInsurance
                            (     
                             bytes32 flightKey,   
                             uint payment, 
                             address customerAddress                       
                            )
                            external
                            requireIsOperational
                            requireIsFlight(flightKey)
                            payable
    {
        Flight storage flight = flights[flightKey];  
        flight.flightInsurances[customerAddress] = payment;   
        customers.push(customerAddress);
        insureeCredit[flight.airlineAddress] = flight.ticketFee;   
        emit boughtInsurance(flightKey,customerAddress,payment);   
    }

    /**
    * @dev Check already bought insurance
    *
    */  
    function checkBoughtInsurance
                                (   
                                    address airline,
                                    string flightCode,
                                    uint256 departureTime,
                                    address customerAddress
                                )
                                public
                                view
                                returns(uint payment)
    {
        bytes32 flightKey = getFlightKey(airline, flightCode, departureTime);
        Flight storage flight = flights[flightKey];
        payment = flight.flightInsurances[customerAddress];
    }

    /**
    * @dev check already bought flight ticket
    *
    */  
    function checkBoughtFlightTicket
                                (
                                    address airline,
                                    string flightCode,
                                    uint256 departureTime,
                                    address customerAddress
                                )
                                public
                                view
                                returns(bool boughtTicket)
    {
        bytes32 flightKey = getFlightKey(airline, flightCode, departureTime);
        Flight storage flight = flights[flightKey];
        boughtTicket = flight.flightBookings[customerAddress];
    }

    /**
     *  @dev Credits payouts to insurees
    */
    function creditInsurees
                    (
                        bytes32 flightKey
                    )
                    internal
                    requireIsOperational
                    requireIsFlight(flightKey)
    {
        Flight storage flight = flights[flightKey];
        for (uint i = 0; i < customers.length; i++) {
            insureeCredit[customers[i]] = flight.flightInsurances[customers[i]];
            emit creditInsurance(flight.flightInsurances[customers[i]],customers[i]);
        }
    }

    function processFlightStatus
                        (
                            bytes32 flightKey,
                            uint8 statusCode
                        )
                            external
                            requireIsOperational
                            requireIsFlight(flightKey) 
                            requiredNoProccessPaymentInsuree(flightKey)
    {
        Flight storage flight = flights[flightKey];

        flight.statusCode = statusCode;
        //statusCode 20 = to flight delay due to airline
        if (statusCode == 20) {
            creditInsurees(flightKey);
        }
    }
    

    /**
     *  @dev Transfers eligible payout funds to insuree
     *
    */
    function pay
            (
                address customer
            )
            external
    {
        require(insureeCredit[customer] > 0, "There is no insurance payment"); 
        uint payment = insureeCredit[customer];
        insureeCredit[customer] = 0;
        customer.transfer(payment);
        emit insurancePaid(payment, customer);
    }

   /**
    * @dev Initial funding for the insurance. Unless there are too many delayed flights
    *      resulting in insurance payouts, the contract should be self-sustaining
    *
    */   
    function fund
                            (   
                            )
                            public
                            payable
    {
    }

    /**
    * @dev function for fetching flight key
    *
    */
    function getFlightKey
                        (
                            address airline,
                            string flightCode,
                            uint256 departureTime
                        )
                        pure
                        public
                        returns(bytes32) 
    {
        return keccak256(abi.encodePacked(airline, flightCode, departureTime));
    }
    
    /**
    * @dev fucntion for fetching ticket
    *
    */
    function getTicketFee
                        (
                            bytes32 flightKey
                        )
                        view
                        external
                        returns (uint ticketFee)
    {
      return flights[flightKey].ticketFee;                    
    }

    /**
    * @dev Fallback function for funding smart contract.
    *
    */
    function() 
                            external 
                            payable 
    {
        require(msg.data.length == 0,"Fallback function,data must be greater than Zero to proceed");
        fund(msg.sender);
    }


}

