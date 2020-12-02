
import web3service from './web3service.js';
const express = require('express');

const bindTo = (expressApp, path) => {
  let router = express.Router();
  router.get('/getRegisteredFlights', getRegisteredFlights);
  router.get('/fetchFlight', fetchFlight);
  expressApp.use(path, router);
}
 
const getRegisteredFlights = async (req, res, next) => {
  res.setHeader("Access-Control-Allow-Origin", "*");
  res.send(await web3service.getRegisteredFlights());
}
const fetchFlight = async (req, res, next) => {
  let fetchDetails = await web3service.fetchFlightStatus(req.query.flight);
  res.setHeader("Access-Control-Allow-Origin", "*");
  res.send(fetchDetails);
}

export default {
  bindTo: bindTo
}


