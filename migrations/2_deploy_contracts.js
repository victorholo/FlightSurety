const FlightSuretyApp = artifacts.require("FlightSuretyApp");
const FlightSuretyData = artifacts.require("FlightSuretyData");
const fs = require('fs');
const Web3 = require('web3');
const BigNumber = require('bignumber.js');

module.exports = function (deployer) {

    let firstAirline = '0x113CeF7d3DF2f37Ed37DC3ae7cCC835CC26f255D';
    deployer.deploy(FlightSuretyData, firstAirline)
        .then(() => {
            return deployer.deploy(FlightSuretyApp, FlightSuretyData.address)
                .then(() => {
                    const url = 'http://localhost:8545';
                    let config = {
                        localhost: {
                            url: url,
                            dataAddress: FlightSuretyData.address,
                            appAddress: FlightSuretyApp.address
                        }
                    }

                    fs.writeFileSync(__dirname + '/../src/dapp/config.json', JSON.stringify(config, null, '\t'), 'utf-8');
                    fs.writeFileSync(__dirname + '/../src/server/config.json', JSON.stringify(config, null, '\t'), 'utf-8');
                });
        });

}