//SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.6.0;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";
import "../node_modules/openzeppelin-solidity/contracts/utils/EnumerableSet.sol";

contract FlightSuretyData {
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeMath for uint256;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    mapping(address => bool) authorizedContracts;

    address private contractOwner; // Account used to deploy contract
    bool private operational = true; // Blocks all state changes throughout the contract if false

    EnumerableSet.AddressSet private registeredAirlines;
    EnumerableSet.AddressSet private operationalAirlines;

    struct PassengerInsurance {
        uint256 value;
        address passengerAddress;
    }

    mapping(bytes32 => PassengerInsurance[]) passengerInsurances;
    mapping(address => uint256) passengerClaimableValues;


    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/

    event ClaimableValuesForFlight(
        string flight,
        address airline,
        uint256 timestamp
    );
    
    event PassengerClaim(address addressOfPassenger, uint256 value);

    /**
     * @dev Constructor
     *      The deploying account becomes contractOwner
     */
    constructor(address firstAirline) public {
        contractOwner = msg.sender;
        EnumerableSet.add(registeredAirlines, firstAirline);
    }

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
    modifier requireIsOperational() {
        require(operational, "Contract is currently not operational");
        _; // All modifiers require an "_" which indicates where the function body will be added
    }

    /**
     * @dev Modifier that requires the "ContractOwner" account to be the function caller
     */
    modifier requireContractOwner() {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }

    modifier requireAuthorizedContract() {
        require(
            authorizedContracts[msg.sender],
            "Caller is not an authorized contract"
        );
        _;
    }

    modifier requireRegisteredAirline(address addressOfAirline) {
        require(
            EnumerableSet.contains(registeredAirlines, addressOfAirline),
            "Caller is not an authorized contract"
        );
        _;
    }

    modifier requireInsureeToHaveValue(address insureeAddress) {
        require(
            passengerClaimableValues[insureeAddress] > 0,
            "Passenger doesn't have any value to claim"
        );
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

    function isOperational() public view returns (bool) {
        return operational;
    }

    /**
     * @dev Sets contract operations on/off
     *
     * When operational mode is disabled, all write transactions except for this one will fail
     */

    function setOperatingStatus(bool mode) external requireContractOwner {
        operational = mode;
    }

    function authorizeCaller(address contractAddress)
        external
        requireContractOwner
    {
        authorizedContracts[contractAddress] = true;
    }

    function deauthorizeCaller(address contractAddress)
        external
        requireContractOwner
    {
        delete authorizedContracts[contractAddress];
    }

    function isAirlineRegistered(address airlineAddress)
        external
        view
        requireAuthorizedContract
        returns (bool)
    {
        return EnumerableSet.contains(registeredAirlines, airlineAddress);
    }

    function isAirlineOperational(address airlineAddress)
        external
        view
        requireAuthorizedContract
        returns (bool)
    {
        return
            EnumerableSet.contains(registeredAirlines, airlineAddress) &&
            EnumerableSet.contains(operationalAirlines, airlineAddress);
    }

    function isInsuredPassenger(string calldata flight,
        address airline,
        uint256 timestamp,
        address passengerAddress) external view returns (bool) {
            bytes32 flightKey = getFlightKey(airline, flight, timestamp);

            //Get all the passengers which have insurance for flight
        PassengerInsurance[] storage passengerInsurancesForFlight
            = passengerInsurances[flightKey];

        for (uint256 i = 0; i < passengerInsurancesForFlight.length; i++) {
            if(passengerAddress == passengerInsurancesForFlight[i]
                .passengerAddress){ return true;
}
        }
            return false;
        }
    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

    /**
     * @dev Add an airline to the registration queue
     *      Can only be called from FlightSuretyApp contract
     */

    function registerAirline(address addressToRegister)
        external
        requireAuthorizedContract
    {
        EnumerableSet.add(registeredAirlines, addressToRegister);
    }

    function noOfOperationalAirlines()
        external
        view
        requireAuthorizedContract
        returns (uint256)
    {
        return EnumerableSet.length(operationalAirlines);
    }

    /**
     * @dev Buy insurance for a flight
     */
    function buy(
        address passengerAddress,
        string calldata flight,
        address airline,
        uint256 timestamp
    ) external payable requireAuthorizedContract {
    emit PassengerClaim(passengerAddress, msg.value);
        bytes32 flightKey = getFlightKey(airline, flight, timestamp);

        //Add new passenger insurance for the flight
        passengerInsurances[flightKey].push(
            PassengerInsurance({
                value: msg.value,
                passengerAddress: passengerAddress
            })
        );
    }

    /**
     *  @dev Credits payouts to insurees
     */
    function creditInsurees(
        string calldata flight,
        address airline,
        uint256 timestamp
    ) external requireAuthorizedContract {
        bytes32 flightKey = getFlightKey(airline, flight, timestamp);

        //Get all the passengers which need to be credited for the flight
        PassengerInsurance[] memory passengerInsurancesForFlight
            = passengerInsurances[flightKey];

        for (uint256 i = 0; i < passengerInsurancesForFlight.length; i++) {
            address passengerAddress = passengerInsurancesForFlight[i]
                .passengerAddress;

            uint256 insuranceValue = passengerInsurancesForFlight[i].value + passengerInsurancesForFlight[i].value.div(2);
            //Add the insurance value to the address of the passenger as he might have other values pending
            uint256 passengerInsurance = passengerClaimableValues[passengerAddress];
            passengerClaimableValues[passengerAddress] = passengerInsurance.add(insuranceValue);
        }

        delete passengerInsurances[flightKey];
        
        emit ClaimableValuesForFlight(flight, airline, timestamp);
    }

    /**
     *  @dev Transfers eligible payout funds to insuree
     */
    function pay(address payable insureeAddress)
        external
        payable
        requireInsureeToHaveValue(insureeAddress)
    {
        uint256 valueToBeClaimed = passengerClaimableValues[insureeAddress];
        delete passengerClaimableValues[insureeAddress];
        insureeAddress.transfer(valueToBeClaimed);
    }

    /**
     * @dev Initial funding for the insurance. Unless there are too many delayed flights
     *      resulting in insurance payouts, the contract should be self-sustaining
     */
    function fund(address fundingAddress)
        external
        payable
        requireAuthorizedContract
        requireRegisteredAirline(fundingAddress)
    {
        EnumerableSet.add(operationalAirlines, fundingAddress);
    }

    function getFlightKey(
        address airline,
        string memory flight,
        uint256 timestamp
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    function doesPassengerHaveClaimableInsurance(address passengerAddress) external view returns (bool) {
        return passengerClaimableValues[passengerAddress] > 0;
    }
    /**
     * @dev Fallback function for funding smart contract.
     */
    receive() external payable {}
}
