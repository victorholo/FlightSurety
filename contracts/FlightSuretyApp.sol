//SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.6.0;

// It's important to avoid vulnerabilities due to numeric overflow bugs
// OpenZeppelin's SafeMath library, when used correctly, protects agains such bugs
// More info: https://www.nccgroup.trust/us/about-us/newsroom-and-events/blog/2018/november/smart-contract-insecurity-bad-arithmetic/

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";
import "./FlightSuretyData.sol";

/************************************************** */
/* FlightSurety Smart Contract                      */
/************************************************** */

contract FlightSuretyApp {
    using SafeMath for uint256; // Allow SafeMath functions to be called for all uint256 types (similar to "prototype" in Javascript)
    using EnumerableSet for EnumerableSet.AddressSet;

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

    uint256 private constant MIN_AIRLINE_FEE = 10 ether;
    uint256 private constant MAX_INSURANCE_PRICE = 1 ether;

    address private contractOwner; // Account used to deploy contract

    struct Flight {
        bool isRegistered;
        uint8 statusCode;
        uint256 timestamp;
        address airline;
    }

    mapping(bytes32 => Flight) private flights;
    string[] private availableFlightCodes;

    mapping(address => address[]) private pendingAirlineRegistrations;

    FlightSuretyData flightSuretyData;

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
        // Modify to call data contract's status
        require(isOperational(), "Contract is currently not operational");
        _; // All modifiers require an "_" which indicates where the function body will be added
    }

    /**
     * @dev Modifier that requires the "ContractOwner" account to be the function caller
     */
    modifier requireContractOwner() {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }

    modifier requireRegisteredAirline() {
        require(
            flightSuretyData.isAirlineRegistered(msg.sender),
            "Caller is not a registered airline"
        );
        _;
    }

    modifier requireOperationalAirline() {
        require(
            flightSuretyData.isAirlineOperational(msg.sender),
            "Caller is not a registered airline"
        );
        _;
    }

    modifier requireAirlineToNotBeRegistered(address addressToRegister) {
        require(
            !flightSuretyData.isAirlineRegistered(addressToRegister),
            "Airline is already registered"
        );
        _;
    }

    modifier requireAddressNotToHaveVotedFor(address airlineToRegister) {
        bool hasAddressVoted = false;

        //address[] storage addressesWhoVoted = pendingAirlineRegistrations[airlineToRegister].addressesWhoVoted;
        for (
            uint256 i = 0;
            i < pendingAirlineRegistrations[airlineToRegister].length;
            i++
        ) {
            if (
                pendingAirlineRegistrations[airlineToRegister][i] == msg.sender
            ) {
                hasAddressVoted = true;
                break;
            }
        }

        require(!hasAddressVoted, "Address has already voted");
        _;
    }

    modifier requireMinimumFee() {
        require(
            msg.value >= MIN_AIRLINE_FEE,
            "Payment is less than the required minimum"
        );
        _;
    }

    modifier requireMaxInsurancePrice() {
        require(
            msg.value <= MAX_INSURANCE_PRICE,
            "Payment is more than the max insurance price allowed"
        );
        _;
    }

    modifier requireFlightToBeRegistered(string memory flight) {
        bytes32 key = keccak256(abi.encodePacked(flight));
        require(
            flights[key].isRegistered, "Flight needs to be registed"
        );
        _;
    }

    modifier requireNotInsured(string memory flight) {
        bytes32 key = keccak256(abi.encodePacked(flight));
        require(!flightSuretyData.isInsuredPassenger(flight, flights[key].airline, flights[key].timestamp, msg.sender), "Passenger already insured for flight");
        _;
    }
    /********************************************************************************************/
    /*                                       CONSTRUCTOR                                        */
    /********************************************************************************************/

    /**
     * @dev Contract constructor
     *
     */
    constructor(address payable dataContract) public {
        contractOwner = msg.sender;
        flightSuretyData = FlightSuretyData(dataContract);
    }

    /********************************************************************************************/
    /*                                            EVENTS                                        */
    /********************************************************************************************/

    event IsOperationalAirline(address operationalAddress);
    
    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    function isOperational() public view returns (bool) {
        return flightSuretyData.isOperational(); // Modify to call data contract's status
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

    /**
     * @dev Add an airline to the registration queue
     *
     */

    function registerAirline(address airlineToRegister)
        external
        requireOperationalAirline
        requireAirlineToNotBeRegistered(airlineToRegister)
        requireAddressNotToHaveVotedFor(airlineToRegister)
        returns (
            bool success,
            uint256 votes,
            uint256 requiredQuorum
        )
    {
        requiredQuorum = quorumForRegistration();
        pendingAirlineRegistrations[airlineToRegister].push(msg.sender);

        votes = pendingAirlineRegistrations[airlineToRegister].length;
        success = requiredQuorum == votes;

        if (success) {
            //quorum is met by this vote, registering airline in data contract.
            delete pendingAirlineRegistrations[airlineToRegister];
            flightSuretyData.registerAirline(airlineToRegister);
        }
    }

    function quorumForRegistration() public view returns (uint256 quorum) {
        uint256 operationalAirlines = flightSuretyData
            .noOfOperationalAirlines();
        if (operationalAirlines < 4) {
            quorum = 1;
        } else {
            quorum = flightSuretyData.noOfOperationalAirlines().div(2);
            uint256 modulo = flightSuretyData.noOfOperationalAirlines().mod(2);
            quorum.add(modulo);
        }
    }

    function startAirlineOperations()
        external
        payable
        requireRegisteredAirline
        requireMinimumFee
    {
        //we will need to fund through the app contract as we may decide to change the minimum fee in the future
        flightSuretyData.fund{value: msg.value}(msg.sender);
        emit IsOperationalAirline(msg.sender);
    }

    /**
     * @dev Register a future flight for insuring.
     *
     */
    function registerFlight(
        string calldata flight,
        uint256 timestamp,
        address airline
    ) external requireOperationalAirline {
        bytes32 key = keccak256(abi.encodePacked(flight));
        flights[key] = Flight({
            isRegistered: true,
            statusCode: STATUS_CODE_UNKNOWN,
            timestamp: timestamp,
            airline: airline
        });
        availableFlightCodes.push(flight);
    }

    function getNumberOfFlights() external view returns (uint256) {
        return availableFlightCodes.length;
    }

    function getFlightByIndex(uint256 index) external view returns (string memory) {
        if (index < availableFlightCodes.length) {
            return availableFlightCodes[index];
        }
        return "";
    }

    /**
     * @dev Called after oracle has updated flight status
     *
     */
    function processFlightStatus(
        address airline,
        string memory flight,
        uint256 timestamp,
        uint8 statusCode
    ) internal {
        bytes32 flightKey = keccak256(abi.encodePacked(flight));
        flights[flightKey].statusCode = statusCode;
        if (statusCode == STATUS_CODE_LATE_AIRLINE) {
            flightSuretyData.creditInsurees(flight, airline, timestamp);
        }
    }

    /**
     * @dev buy insurance
     *
     */
    function buyInsurance(string memory flight)
        public
        payable
        requireNotInsured(flight)
        requireMaxInsurancePrice
    {
        bytes32 key = keccak256(abi.encodePacked(flight));
        flightSuretyData.buy{value: msg.value}(
            msg.sender,
            flight,
            flights[key].airline,
            flights[key].timestamp
        );
    }

    // Generate a request for oracles to fetch flight information
    function fetchFlightStatus(string memory flight) external requireFlightToBeRegistered(flight) {
        uint8 index = getRandomIndex(msg.sender);
        bytes32 flightKey = keccak256(abi.encodePacked(flight));
        // Generate a unique key for storing the request
        bytes32 key = keccak256(
            abi.encodePacked(
                index,
                flights[flightKey].airline,
                flight,
                flights[flightKey].timestamp
            )
        );
        oracleResponses[key] = ResponseInfo({
            requester: msg.sender,
            isOpen: true
        });

        emit OracleRequest(
            index,
            flights[flightKey].airline,
            flight,
            flights[flightKey].timestamp
        );
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
        address requester; // Account that requested status
        bool isOpen; // If open, oracle responses are accepted
        mapping(uint8 => address[]) responses; // Mapping key is the status code reported
        // This lets us group responses and identify
        // the response that majority of the oracles
    }

    // Track all oracle responses
    // Key = hash(index, flight, timestamp)
    mapping(bytes32 => ResponseInfo) private oracleResponses;

    // Event fired each time an oracle submits a response
    event FlightStatusInfo(
        address airline,
        string flight,
        uint256 timestamp,
        uint8 status
    );

    event OracleReport(
        address airline,
        string flight,
        uint256 timestamp,
        uint8 status
    );

    // Event fired when flight status request is submitted
    // Oracles track this and if they have a matching index
    // they fetch data and submit a response
    event OracleRequest(
        uint8 index,
        address airline,
        string flight,
        uint256 timestamp
    );

    // Register an oracle with the contract
    function registerOracle() external payable {
        // Require registration fee
        require(msg.value >= REGISTRATION_FEE, "Registration fee is required");

        uint8[3] memory indexes = generateIndexes(msg.sender);

        oracles[msg.sender] = Oracle({isRegistered: true, indexes: indexes});
    }

    function getMyIndexes() external view returns (uint8[3] memory) {
        require(
            oracles[msg.sender].isRegistered,
            "Not registered as an oracle"
        );

        return oracles[msg.sender].indexes;
    }

    // Called by oracle when a response is available to an outstanding request
    // For the response to be accepted, there must be a pending request that is open
    // and matches one of the three Indexes randomly assigned to the oracle at the
    // time of registration (i.e. uninvited oracles are not welcome)
    function submitOracleResponse(
        uint8 index,
        address airline,
        string calldata flight,
        uint8 statusCode
    ) external {
        require(
            (oracles[msg.sender].indexes[0] == index) ||
                (oracles[msg.sender].indexes[1] == index) ||
                (oracles[msg.sender].indexes[2] == index),
            "Index does not match oracle request"
        );

        bytes32 flightsKey = keccak256(
            abi.encodePacked(flight)
        );
        uint256 timestamp = flights[flightsKey].timestamp;
        bytes32 key = keccak256(
            abi.encodePacked(index, airline, flight, timestamp)
        );
        require(
            oracleResponses[key].isOpen,
            "Flight requests are closed"
        );

        oracleResponses[key].responses[statusCode].push(msg.sender);

        // Information isn't considered verified until at least MIN_RESPONSES
        // oracles respond with the *** same *** information
        emit OracleReport(airline, flight, timestamp, statusCode);
        if (
            oracleResponses[key].responses[statusCode].length >= MIN_RESPONSES
        ) {
            emit FlightStatusInfo(airline, flight, timestamp, statusCode);

            oracleResponses[key].isOpen = false;
            // Handle flight status as appropriate
            processFlightStatus(airline, flight, timestamp, statusCode);
        }
    }

    function getFlightKey(
        address airline,
        string memory flight,
        uint256 timestamp
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    // Returns array of three non-duplicating integers from 0-9
    function generateIndexes(address account)
        internal
        returns (uint8[3] memory)
    {
        uint8[3] memory indexes;
        indexes[0] = getRandomIndex(account);

        indexes[1] = indexes[0];
        while (indexes[1] == indexes[0]) {
            indexes[1] = getRandomIndex(account);
        }

        indexes[2] = indexes[1];
        while ((indexes[2] == indexes[0]) || (indexes[2] == indexes[1])) {
            indexes[2] = getRandomIndex(account);
        }

        return indexes;
    }

    // Returns array of three non-duplicating integers from 0-9
    function getRandomIndex(address account) internal returns (uint8) {
        uint8 maxValue = 10;

        // Pseudo random number...the incrementing nonce adds variation
        uint8 random = uint8(
            uint256(
                keccak256(
                    abi.encodePacked(blockhash(block.number - nonce++), account)
                )
            ) % maxValue
        );

        if (nonce > 250) {
            nonce = 0; // Can only fetch blockhashes for last 256 blocks so we adapt
        }

        return random;
    }

    // endregion
}
