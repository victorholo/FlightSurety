
var Test = require('../config/testConfig.js');
const truffleAssert = require('truffle-assertions');
contract('Oracles', async (accounts) => {
  const TEST_ORACLES_COUNT = 20;
  var config;
  before('setup contract', async () => {
    config = await Test.Config(accounts);

    // Watch contract events
    const STATUS_CODE_UNKNOWN = 0;
    const STATUS_CODE_ON_TIME = 10;
    const STATUS_CODE_LATE_AIRLINE = 20;
    const STATUS_CODE_LATE_WEATHER = 30;
    const STATUS_CODE_LATE_TECHNICAL = 40;
    const STATUS_CODE_LATE_OTHER = 50;

    //register first airline and a flight
    await config.flightSuretyData.authorizeCaller(config.flightSuretyApp.address);
    await config.flightSuretyApp.startAirlineOperations({ from: config.firstAirline, value: 10 * config.weiMultiple });

    let timestamp = Math.floor(Date.now() / 1000);
    await config.flightSuretyApp.registerFlight(config.flight, timestamp, config.firstAirline, { from: config.firstAirline });
  });


  it('(oracles) can register oracles', async () => {

    // ARRANGE
    let fee = await config.flightSuretyApp.REGISTRATION_FEE.call();

    // ACT
    for (let a = 1; a < TEST_ORACLES_COUNT; a++) {
      await config.flightSuretyApp.registerOracle({ from: accounts[a], value: fee });
      let result = await config.flightSuretyApp.getMyIndexes.call({ from: accounts[a] });
      console.log(`Oracle Registered: ${result[0]}, ${result[1]}, ${result[2]}`);
    }
  });

  it('(passenger) can add insurance and is not ensured more then once', async () => {

    await config.flightSuretyApp.buyInsurance(config.flight, { from: accounts[5], value: 1 * config.weiMultiple });

    let assertionString = "";
    let expectedString = "Passenger already insured for flight";

    try {
      await config.flightSuretyApp.buyInsurance(config.flight, { from: accounts[5], value: 1 * config.weiMultiple });
    } catch (e) {
      assertionString = e;
    }

    assert.equal(String(assertionString).includes(expectedString), true, "Passenger should not be insured for the same flight more then once");
  });

  it('(oracles) can request flight status', async () => {

    // Submit a request for oracles to get status information for a flight
    let result = await config.flightSuretyApp.fetchFlightStatus(config.flight);
    // ACT

    let oracleIndex = -1;
    truffleAssert.eventEmitted(result, 'OracleRequest', (ev) => {
      oracleIndex = ev.index;
      return ev.index >= 0;
    });
    // Since the Index assigned to each test account is opaque by design
    // loop through all the accounts and for each account, all its Indexes (indices?)
    // and submit a response. The contract will reject a submission if it was
    // not requested so while sub-optimal, it's a good test of that feature
    for (let a = 1; a < TEST_ORACLES_COUNT; a++) {

      // Get oracle information
      let oracleIndexes = await config.flightSuretyApp.getMyIndexes.call({ from: accounts[a] });
      for (let idx = 0; idx < 3; idx++) {
        if (parseInt(oracleIndexes[idx]) !== parseInt(oracleIndex)) {
          continue;
        }

        try {
          // Submit a response...it will only be accepted if there is an Index match
          let results = await config.flightSuretyApp.submitOracleResponse(oracleIndexes[idx], config.firstAirline, config.flight, 20, { from: accounts[a] });
          // console.log(a + " oracle output:");
          // truffleAssert.prettyPrintEmittedEvents(results);
          truffleAssert.eventEmitted(results, 'OracleReport', (ev) => {
            return ev.flight === config.flight;
          });
        } catch (e) {
          //console.log(e.reason);
        }
      }

    }

  });

  it('(passenger) has claimable values', async () => {
    let result = await config.flightSuretyData.doesPassengerHaveClaimableInsurance.call(accounts[5]);
    assert.equal(result, true);
  });

  it('(passenger) is retrieving payment when flight is late by airline, and is credited the right amount', async () => {
    let Web3 = require('web3');
    let provider = 'http://127.0.0.1:8545/';
    let web3Provider = await new Web3.providers.HttpProvider(provider);
    let web3 = await new Web3(web3Provider);

    let value = await web3.eth.getBalance(accounts[5]);
    await config.flightSuretyData.pay(accounts[5]);
    assert.equal(+value + +(1.5 * +config.weiMultiple), await web3.eth.getBalance(accounts[5]))
  });
});
