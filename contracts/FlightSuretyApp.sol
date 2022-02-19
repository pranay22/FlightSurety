pragma solidity ^0.4.25;

// It's important to avoid vulnerabilities due to numeric overflow bugs
// OpenZeppelin's SafeMath library, when used correctly, protects agains such bugs
// More info: https://www.nccgroup.trust/us/about-us/newsroom-and-events/blog/2018/november/smart-contract-insecurity-bad-arithmetic/

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

/************************************************** */
/* FlightSurety Smart Contract                      */
/************************************************** */
contract FlightSuretyApp {
    using SafeMath for uint256; // Allow SafeMath functions to be called for all uint256 types (similar to "prototype" in Javascript)

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    // Flight status codees
    uint8 private constant STATUS_CODE_UNKNOWN = 0;
    uint8 private constant STATUS_CODE_ON_TIME = 10;
    uint8 private constant STATUS_CODE_LATE_AIRLINE = 20;
    uint8 private constant STATUS_CODE_LATE_WEATHER = 30;
    uint8 private constant STATUS_CODE_LATE_TECHNICAL = 40;
    uint8 private constant STATUS_CODE_LATE_OTHER = 50;

    address private contractOwner;          // Account used to deploy contract

    struct Flight {
        bool isRegistered;
        uint8 statusCode;
        uint256 updatedTimestamp;        
        address airline;
    }
    mapping(bytes32 => Flight) private flights;

    // adding data contract
    FlightSuretyData flightSuretyData;
    
    //multiparty-consensus
    mapping (address => address[]) public multiCalls;

    //minimum payment for airline to be registered
    uint public minPayment = 10 ether;

 
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
        // Modify to call data contract's status
        require(true, "Contract is currently not operational");  
        _;  // All modifiers require an "_" which indicates where the function body will be added
    }

    /**
    * @dev Modifier that requires the "ContractOwner" account to be the function caller
    */
    modifier requireContractOwner()
    {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }

    modifier requireEnoughFunds(){
        require(msg.value >= minPayment, "It is needed at least 10ETH to register");
        _;
    }
    modifier requirePaidRegistration()
    {
        require(flightSuretyData.paidRegistration(msg.sender), "Airline needs to pay registration fee");
        _;
    }

    modifier requireIsAirline()
    {
        require(flightSuretyData.isAirline(msg.sender), "Airline needs to be registered");
        _; 
    }

     modifier requireMinimumPayment() {
        require(msg.value >= minPayment, "Requires 10 ETH to be registered");
        _;
    }

    modifier requirePaymentBuyTicketAndInsurance(address airline, string flightCode, uint256 departureTime, uint payment) {
        require(payment >= flightSuretyData.getTicketFee(getFlightKey(airline, flightCode, departureTime)).add(1 ether)
                , "Requires greater payment to get ticket and Insurance");
        _;
    }

    /********************************************************************************************/
    /*                                       CONSTRUCTOR                                        */
    /********************************************************************************************/

    /**
    * @dev Contract constructor
    *
    */
    constructor
                                (
                                    address contractAddress
                                ) 
                                public 
    {
        contractOwner = msg.sender;
        flightSuretyData = FlightSuretyData(contractAddress);
    }

    /********************************************************************************************/
    /*                                       EVENTS                                             */
    /********************************************************************************************/

    // Register an event for flight registration
    event registeredFlight(address airlineAddress, string flightCode, string destination, uint256 departureTime);
    // Insurance
    event paidInsurance(address customer);
    // Flight status, processed
    event processedFlightStatus(string destination, string flightCode,uint256 departureTime,uint8 statusCode);
    // Already registered oracles
    event registeredOracles(uint8[3] indexes);

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    function isOperational() 
                            public 
                            view 
                            returns(bool) 
    {
        return (flightSuretyData.isOperational());  // Modify to call data contract's status
    }

    function setOperatingStatus
                            (
                                bool mode
                            ) 
                            external
    {
        flightSuretyData.setOperatingStatus(mode); 
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

  
   /**
    * @dev Add an airline to the registration queue
    *
    */   
    function registerAirline
                        (
                            string name,   
                            address newAirline   
                        )
                        requirePaidRegistration
                        requireIsAirline
                        external
    {
        if(flightSuretyData.totalRegisteredAirlines() < 4){
            flightSuretyData.registerAirline(name, newAirline, msg.sender);
        } else{
            bool isDuplicate = false;
            for(uint c = 0; c < multiCalls[newAirline].length; c++) {
                if (multiCalls[newAirline][c] == msg.sender) {
                    isDuplicate = true;
                    break;
                }
            }
            require(!isDuplicate, "Caller has already called this function.");
            multiCalls[newAirline].push(msg.sender);
            // Multiparty Consensus >= 50%
            if (multiCalls[newAirline].length >= flightSuretyData.totalRegisteredAirlines().div(2)) {     
                multiCalls[newAirline] = new address[](0);     
                flightSuretyData.registerAirline(name, newAirline, msg.sender);
            }
        }
    }

    function fund 
                 (
                 )
                 external
                 requireIsOperational
                 requireEnoughFunds
                 payable
    {
        flightSuretyData.fund.value(msg.value)(msg.sender); 
    }


   /**
    * @dev Register a future flight for insuring.
    *
    */  
    function registerFlight
                        (
                            uint statusCode,
                            string flightCode,
                            string origin,
                            string destination,
                            uint256 departureTime,
                            uint ticketFee
                        )
                        external
                        requireIsOperational
                        requirePaidRegistration
    {
        flightSuretyData.registerFlight(
            statusCode,
            flightCode,
            origin,
            destination,
            departureTime,
            ticketFee,
            msg.sender
        );
        // emit event for flight registration
        emit registeredFlight(msg.sender, flightCode, destination, departureTime);
    }

    function getFlightKey
                    (
                        address airline,
                        string flightCode,
                        uint256 departureTime
                    )
                    view
                    internal
                    returns(bytes32)
    {
        return flightSuretyData.getFlightKey(airline, flightCode, departureTime);
    } 

    function getFlightTicketAndBuyInsurance
                                    (
                                        address airline,
                                        string flightCode,
                                        uint256 departureTime,  
                                        address customerAddress,
                                        uint payment 
                                    )
                                    external
                                    requirePaymentBuyTicketAndInsurance(airline, flightCode, departureTime, payment)
                                    payable
    {
        bytes32 flightKey = getFlightKey(airline, flightCode, departureTime); 
        uint total = flightSuretyData.getTicketFee(flightKey).add(1 ether);
        if(msg.value > total){
            uint change = msg.value - total;
            msg.sender.transfer(change);
        } 
        flightSuretyData.getFlightTicket(flightKey,customerAddress);
        flightSuretyData.buyFligthAndInsurance.value(msg.value)(flightKey,payment,customerAddress);
    }

    function payInsurance
                    (
                    )
                    external
                    requireIsOperational
    {
        flightSuretyData.pay(msg.sender);
        emit paidInsurance(msg.sender);
    }
    
   /**
    * @dev Called after oracle has updated flight status
    *
    */  
    function processFlightStatus
                            (
                                address airline,
                                string destination,
                                string flightCode,
                                uint256 departureTime,
                                uint8 statusCode
                            )
                            internal
                            requireIsOperational
    {
        bytes32 flightKey = getFlightKey(airline, flightCode, departureTime); 
        flightSuretyData.processFlightStatus(flightKey, statusCode);
        emit processedFlightStatus(destination, flightCode, departureTime, statusCode);
    }


    // Generate a request for oracles to fetch flight information based on flightCode
    function fetchFlightStatus
                        (
                            address airline,
                            string flightCode,
                            uint256 timestamp                            
                        )
                        external
    {
        uint8 index = getRandomIndex(msg.sender);
        // Generate a unique key for storing the request
        bytes32 uKey = keccak256(abi.encodePacked(index, airline, flightCode, timestamp));
        oracleResponses[uKey] = ResponseInfo({
                                                requester: msg.sender,
                                                isOpen: true
                                            });
        emit OracleRequest(index, airline, flightCode, timestamp);
    } 

    function referralsMissing
                        (
                            address newAirline
                        )
                        public
                        view
                        returns(uint missReferrals)
    {
        uint referrals = multiCalls[newAirline].length;
        uint half = flightSuretyData.totalRegisteredAirlines().div(2);
        missReferrals = half.sub(referrals);
    }

// region ORACLE MANAGEMENT

    // Incremented to add pseudo-randomness at various points
    uint8 private nonce = 0;    

    // Fee to be paid when registering oracle
    uint256 public constant REGISTRATION_FEE = 1 ether;

    // Number of oracles that must respond for valid status
    uint256 private constant MIN_RESPONSES = 3;


    struct Oracle {
        bool isRegistered;
        uint8[3] indexes;        
    }

    // Track all registered oracles
    mapping(address => Oracle) private oracles;

    // Model for responses from oracles
    struct ResponseInfo {
        address requester;                              // Account that requested status
        bool isOpen;                                    // If open, oracle responses are accepted
        mapping(uint8 => address[]) responses;          // Mapping key is the status code reported
                                                        // This lets us group responses and identify
                                                        // the response that majority of the oracles
    }

    // Track all oracle responses
    // Key = hash(index, flight, timestamp)
    mapping(bytes32 => ResponseInfo) private oracleResponses;

    // Event fired each time an oracle submits a response
    event FlightStatusInfo(address airline, string flightCode, string destination, uint256 departureTime, uint8 status);

    event OracleReport(address airline, string flightCode, string destination, uint256 departureTime, uint8 statusCode);

    // Event fired when flight status request is submitted
    // Oracles track this and if they have a matching index
    // they fetch data and submit a response
    event OracleRequest(uint8 index, address airline, string flight, uint256 timestamp);


    // Register an oracle with the contract
    function registerOracle
                        (
                        )
                        external
                        payable
    {
        // Require registration fee
        require(msg.value >= REGISTRATION_FEE, "Registration fee is required");
        uint8[3] memory indexes = generateIndexes(msg.sender);
        oracles[msg.sender] = Oracle({
                                        isRegistered: true,
                                        indexes: indexes
                                    });
        emit registeredOracles(indexes);
    }

    function getMyIndexes
                            (
                            )
                            view
                            external
                            returns(uint8[3])
    {
        require(oracles[msg.sender].isRegistered, "Not registered as an oracle");

        return oracles[msg.sender].indexes;
    }




    // Called by oracle when a response is available to an outstanding request
    // For the response to be accepted, there must be a pending request that is open
    // and matches one of the three Indexes randomly assigned to the oracle at the
    // time of registration (i.e. uninvited oracles are not welcome)
    function submitOracleResponse
                        (
                            uint8 index,
                            address airline,
                            string destination,
                            string flightCode,
                            uint256 departureTime,
                            uint8 statusCode
                        )
                        external
    {
        require((oracles[msg.sender].indexes[0] == index) || (oracles[msg.sender].indexes[1] == index) || (oracles[msg.sender].indexes[2] == index), "Index does not match oracle request");


        bytes32 key = keccak256(abi.encodePacked(index, airline, flightCode, departureTime)); 
        require(oracleResponses[key].isOpen, "Flight or departure time do not match oracle request");

        oracleResponses[key].responses[statusCode].push(msg.sender);

        // Information isn't considered verified until at least MIN_RESPONSES
        // oracles respond with the *** same *** information
        emit OracleReport(airline, flightCode, destination, departureTime, statusCode);
        if (oracleResponses[key].responses[statusCode].length >= MIN_RESPONSES) {

            emit FlightStatusInfo(airline, flightCode, destination, departureTime, statusCode);

            // Handle flight status as appropriate
            processFlightStatus(airline, destination, flightCode, departureTime, statusCode);
        }
    }

    // Returns array of three non-duplicating integers from 0-9
    function generateIndexes
                            (                       
                                address account         
                            )
                            internal
                            returns(uint8[3])
    {
        uint8[3] memory indexes;
        indexes[0] = getRandomIndex(account);
        
        indexes[1] = indexes[0];
        while(indexes[1] == indexes[0]) {
            indexes[1] = getRandomIndex(account);
        }

        indexes[2] = indexes[1];
        while((indexes[2] == indexes[0]) || (indexes[2] == indexes[1])) {
            indexes[2] = getRandomIndex(account);
        }

        return indexes;
    }

    // Returns array of three non-duplicating integers from 0-9
    function getRandomIndex
                            (
                                address account
                            )
                            internal
                            returns (uint8)
    {
        uint8 maxValue = 10;

        // Pseudo random number...the incrementing nonce adds variation
        uint8 random = uint8(uint256(keccak256(abi.encodePacked(blockhash(block.number - nonce++), account))) % maxValue);

        if (nonce > 250) {
            nonce = 0;  // Can only fetch blockhashes for last 256 blocks so we adapt
        }

        return random;
    }

// endregion

}   

/* 
* FlightSuretyData interface
*/
contract FlightSuretyData{

     struct Airline {
        string name;
        bool isRegistered;
        bool paidRegistration;
    }   
    mapping(address => Airline) airlines;
    uint256 public totalRegisteredAirlines;

    function isOperational() 
                            public 
                            view 
                            returns(bool);

    function setOperatingStatus
                            (
                                bool mode
                            ) 
                            external;

    function paidRegistration
                            (
                               address airlineAddress
                            ) 
                            external
                            view 
                            returns (bool);

    function isAirline
                    (
                        address addressAirline
                    )
                    external
                    view
                    returns (bool);                        

    function fund
                (    
                    address fundAddress
                )
                public
                payable; 

    function getFlightKey
                        (
                            address airline,
                            string flightCode,
                            uint256 departureTime
                        )
                        pure
                        external
                        returns(bytes32);

    function registerAirline
                        ( 
                            string name,
                            address newAirline,
                            address airlineReferral
                        )
                        external;

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
                        external;   
    
    function getTicketFee
                        (
                           bytes32 flightKey
                        )
                        pure
                        external
                        returns (uint);

    function getFlightTicket
                        (
                          bytes32 flightKey, 
                          address customerAddress 

                        )
                        external;


    function buyFligthAndInsurance
                            (     
                             bytes32 flightKey,   
                             uint payment, 
                             address customerAddress                       
                            )
                            external
                            payable;
    function pay(
        address customer
        ) 
        external;

    function processFlightStatus(
        bytes32 flightKey, 
        uint8 statusCode
        )  
        external; 
}