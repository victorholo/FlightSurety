
import http from 'http';
import flightController from './flightController';
import web3service from './web3service.js';
const express = require('express');

const expressApp = express();
expressApp.use(express.json());
expressApp.use(express.urlencoded({ extended: false }));
flightController.bindTo(expressApp, '/api');


web3service.setup().then(() => {
    const server = http.createServer(expressApp)
    server.listen(3000)
    if (module.hot) {
        module.hot.accept('./flightController', () => {
            server.removeListener('request', expressApp)
            server.on('request', expressApp)
        });
    }

    console.log('Started listening on port 3000');
});





