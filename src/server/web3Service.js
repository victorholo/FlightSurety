
import Web3 from 'web3';
import FlightSuretyApp from '../../build/contracts/FlightSuretyApp.json';
import FlightSuretyData from '../../build/contracts/FlightSuretyData.json';
import Config from './config.json';
import BigNumber from 'bignumber.js';

let oracles = [];
const statusCodes = [
    0, 10, 20, 30, 40, 50
];
const weiMutliple = new BigNumber(10).pow(18);
let config = Config['localhost'];
let web3 = new Web3(new Web3.providers.WebsocketProvider(config.url.replace('http', 'ws')));
let flightSuretyApp = new web3.eth.Contract(FlightSuretyApp.abi, config.appAddress);
let flightSuretyData = new web3.eth.Contract(FlightSuretyData.abi, config.dataAddress);
let accounts;

let startListeningForEvents = async () => {
    flightSuretyApp.events.OracleRequest({
        fromBlock: await web3.eth.getBlockNumber()
    }, async function (error, event) {
        if (error) {
            console.log(error)
            return;
        }
        console.log(`A new event is requested for oracles with index ${event.returnValues.index}`);
        for (let i = 0; i < oracles.length; i++) {
            if (oracles[i].indexes.includes(event.returnValues.index)) {
                //submit oracle response
                const status = statusCodes[Math.floor(Math.random() * statusCodes.length)];
                console.log(`Oracle ${oracles[i].account}, with indexes ${JSON.stringify(oracles[i].indexes)}, responding to ${event.returnValues.index} with code ${status}`)
                flightSuretyApp.methods.submitOracleResponse(event.returnValues.index, event.returnValues.airline, event.returnValues.flight, status)
                    .send({ from: oracles[i].account, gas: 3000000 });
            }
        }
    });
}
let setupFirstInteractions = async () => {
    await flightSuretyData.methods.authorizeCaller(config.appAddress).send({ from: accounts[0] });
    const firstFlights = ["DL1937", "EI5321", "EY8252"];
    //first airline has been registered but needs to fund contract
    await flightSuretyApp.methods.startAirlineOperations().send({ from: accounts[0], gas: 3000000, value: 10 * weiMutliple });
    for (let i = 0; i < firstFlights.length; i++) {
        const timestamp = parseInt((new Date().getTime() / 1000).toFixed(0));
        await flightSuretyApp.methods.registerFlight(firstFlights[i], timestamp, accounts[0]).send({ from: accounts[0], gas: 3000000 });
        console.log(`Flight ${firstFlights[i]} registered`);
    }
}

export default {
    setup: async () => {

        accounts = await web3.eth.getAccounts();

        //first airline has been registered but needs to fund contract, also initial flights are set up
        await setupFirstInteractions();

        let fee = await flightSuretyApp.methods.REGISTRATION_FEE().call();

        console.log('Registering oracles...');
        for (let i = 0; i < 20; i++) {
            await flightSuretyApp.methods.registerOracle().send({ from: accounts[i], value: fee, gas: 3000000 });
            let result = await flightSuretyApp.methods.getMyIndexes().call({ from: accounts[i] });

            oracles.push(
                {
                    account: accounts[i],
                    indexes: result
                }
            );
        }

        console.log(JSON.stringify(oracles));
        await startListeningForEvents();
    },
    getRegisteredFlights: async () => {
        let flightNames = [];
        let noOfRegisteredFlights = await flightSuretyApp.methods.getNumberOfFlights().call();
        for (let i = 0; i < noOfRegisteredFlights; i++) {
            flightNames.push(await flightSuretyApp.methods.getFlightByIndex(i).call());
        }
        return flightNames;
    },
    fetchFlightStatus: async (flightName) => {
        let result = await flightSuretyApp.methods.fetchFlightStatus(flightName).send({ from: accounts[0] });
        return {
            'index': result.events.OracleRequest.returnValues.index,
            'flight': result.events.OracleRequest.returnValues.flight,
            'timestamp': result.events.OracleRequest.returnValues.timestamp,
            'airline': result.events.OracleRequest.returnValues.airline
        };
    }
}