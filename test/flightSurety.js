
var Test = require('../config/testConfig.js');
var BigNumber = require('bignumber.js');

contract('Flight Surety Tests', async (accounts) => {

    var config;
    before('setup contract', async () => {
        config = await Test.Config(accounts);
        await config.flightSuretyData.authorizeCaller(config.flightSuretyApp.address);
        await config.flightSuretyApp.startAirlineOperations({ from: config.firstAirline, value: 10 * config.weiMultiple });
    });

    /****************************************************************************************/
    /* Operations and Settings                                                              */
    /****************************************************************************************/

    it(`(multiparty) has correct initial isOperational() value`, async function () {

        // Get operating status
        let status = await config.flightSuretyData.isOperational.call();
        assert.equal(status, true, "Incorrect initial operating status value");

    });

    it(`(multiparty) can block access to setOperatingStatus() for non-Contract Owner account`, async function () {

        // Ensure that access is denied for non-Contract Owner account
        let accessDenied = false;
        try {
            await config.flightSuretyData.setOperatingStatus(false, { from: config.testAddresses[2] });
        }
        catch (e) {
            accessDenied = true;
        }
        assert.equal(accessDenied, true, "Access not restricted to Contract Owner");

    });

    it(`(multiparty) can allow access to setOperatingStatus() for Contract Owner account`, async function () {

        // Ensure that access is allowed for Contract Owner account
        let accessDenied = false;
        try {
            await config.flightSuretyData.setOperatingStatus(false);
        }
        catch (e) {
            accessDenied = true;
        }
        assert.equal(accessDenied, false, "Access not restricted to Contract Owner");

    });

    it(`(multiparty) can block access to functions using requireIsOperational when operating status is false`, async function () {

        await config.flightSuretyData.setOperatingStatus(false);

        let reverted = false;
        try {
            await config.flightSurety.setTestingMode(true);
        }
        catch (e) {
            reverted = true;
        }
        assert.equal(reverted, true, "Access not blocked for requireIsOperational");

        // Set it back for other tests to work
        await config.flightSuretyData.setOperatingStatus(true);

    });

    it('(airline) airline is not operational if funding was not provided', async () => {
        //given
        let newAirline = accounts[2];
        await config.flightSuretyApp.registerAirline(newAirline, { from: config.firstAirline });

        //when
        let result = await config.flightSuretyData.isAirlineOperational(newAirline, { from: config.flightSuretyApp.address });

        //then
        assert.equal(result, false, "Airline should not be able to register another airline if it hasn't provided funding");

    });

    it('(airline) airline is operational after funding was provided', async () => {

        let newAirline = accounts[2];
        await config.flightSuretyApp.startAirlineOperations({ from: newAirline, value: 10 * config.weiMultiple });

        //when
        let result = await config.flightSuretyData.isAirlineOperational(newAirline, { from: config.flightSuretyApp.address });

        //then
        assert.equal(result, true, "Airline is operational after registration and funding");

    });

    it('(airline) when 4 or more airlines are registered, quorum is 50%', async () => {

        // ARRANGE - register and fund airlines up to 4
        let newAirline3 = accounts[3];
        await config.flightSuretyApp.registerAirline(newAirline3, { from: config.firstAirline });
        await config.flightSuretyApp.startAirlineOperations({ from: newAirline3, value: 10 * config.weiMultiple });
        let result = await config.flightSuretyData.isAirlineOperational.call(newAirline3, { from: config.flightSuretyApp.address });
        assert.equal(result, true, "Airline is operational after registration and funding");

        let newAirline4 = accounts[4];
        await config.flightSuretyApp.registerAirline(newAirline4, { from: config.firstAirline });
        await config.flightSuretyApp.startAirlineOperations({ from: newAirline4, value: 10 * config.weiMultiple });
        result = await config.flightSuretyData.isAirlineOperational.call(newAirline4, { from: config.flightSuretyApp.address });
        assert.equal(result, true, "Airline is operational after registration and funding");

        result = await config.flightSuretyApp.quorumForRegistration.call();
        assert.equal(result, 2, "Quorum should now be 2");
    });

    it('(airline) when registering new airline when quorum needs to be met, airline is registered after enough votes', async () => {
        const newAirline = accounts[5];

        // first register will not succeed because quorum is not reached
        await config.flightSuretyApp.registerAirline(newAirline, { from: accounts[2] });

        let result = await config.flightSuretyData.isAirlineRegistered.call(newAirline, { from: config.flightSuretyApp.address });
        assert.equal(result, false, "Airline should not be registered if quorum is not reached");

        // second register will succeed because quorum is reached
        await config.flightSuretyApp.registerAirline(newAirline, { from: accounts[3] });

        result = await config.flightSuretyData.isAirlineRegistered.call(newAirline, { from: config.flightSuretyApp.address });
        assert.equal(result, true, "Airline should be registered after quorum reached");
    });

    it('(airline) can register flight', async () => {
        let timestamp = Math.floor(Date.now() / 1000);
        await config.flightSuretyApp.registerFlight(config.flight, timestamp, config.firstAirline, { from: config.firstAirline });

        let result = await config.flightSuretyApp.getFlightByIndex(0);
        assert.equal(config.flight, result);
    });


});
