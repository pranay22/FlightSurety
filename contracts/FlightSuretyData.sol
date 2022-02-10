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
    mapping(address => uint256) private authorizedCaller;

    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/


    /**
    * @dev Constructor
    *      The deploying account becomes contractOwner
    */
    constructor
                                (
                                ) 
                                public 
    {
        authorizedCaller[msg.sender] = 1;
        contractOwner = msg.sender;
        airlines[msg.sender] = Airline({
                                     name: "Genesis Airline",
                                     isRegistered: true,
                                     registrationFee: true
        });

        totalRegisteredAirlines = 1;
    }
    event newAirlineRegistered(address newAirline,address airlineReferral);     // register a new event

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
        require(authorizedCaller[msg.sender] == 1, "Caller is not authorized");
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
        require(authorizedCaller[msg.sender] == 1, "Caller is not authorized");
        operational = mode;
    }

    function authorizeCaller
                            (
                                address callerAddress
                            )
                            external
                            requireContractOwner
    {
        authorizedCaller[callerAddress] = 1;
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

    function isAuthorizedCaller (
                                 address caller
                                 ) 
                                 public 
                                 view  
                                 returns (uint256)
                                  {
        return authorizedCaller[caller]; 
    }

    function isAirlineRegisted(
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
                            requireContractOwner
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


   /**
    * @dev Buy insurance for a flight
    *
    */   
    function buy
                            (                             
                            )
                            external
                            payable
    {

    }

    /**
     *  @dev Credits payouts to insurees
    */
    function creditInsurees
                                (
                                )
                                external
                                pure
    {
    }
    

    /**
     *  @dev Transfers eligible payout funds to insuree
     *
    */
    function pay
                            (
                            )
                            external
                            pure
    {
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

    function getFlightKey
                        (
                            address airline,
                            string memory flight,
                            uint256 timestamp
                        )
                        pure
                        internal
                        returns(bytes32) 
    {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    /**
    * @dev Fallback function for funding smart contract.
    *
    */
    function() 
                            external 
                            payable 
    {
        fund();
    }


}

