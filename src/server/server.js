import FlightSuretyApp from '../../build/contracts/FlightSuretyApp.json';
import Config from './config.json';
import Web3 from 'web3';
import express from 'express';
import {oracleServer} from './serverHelper.js';


let config = Config['localhost'];
let web3 = new Web3(new Web3.providers.WebsocketProvider(config.url.replace('http', 'ws')));
web3.eth.defaultAccount = web3.eth.accounts[0];
let flightSuretyApp = new web3.eth.Contract(FlightSuretyApp.abi, config.appAddress);
const oracles = 20;

/*flightSuretyApp.events.OracleRequest({
    fromBlock: 0
  }, function (error, event) {
    if (error) console.log(error)
    console.log(event)
});*/

oracleServer.init(oracles);


const app = express();
//app.use(bodyParser.json());
app.use(express.json());
app.get('/api', (req, res) => {
    res.send({
      message: 'An API for use with your Dapp!'
    })
  })

app.get('/oracles', (req, res) => {
    res.json(oracleServer.oracles)
})    
app.get('/flights', (req, res) => {
      res.json(oracleServer.flights)
    })   
   
app.get('/flight/:airline/:flightCode/:destination', async (req, res) => {
  const flightKey = await flightSuretyData.methods.getFlightKey(
    req.params.airline,
    req.params.flightCode,
    req.params.destination
    ).call()
  const flight = await flightSuretyData.methods.flights(flightKey).call()
  res.send(flight)
})

app.get('/oracles-response/:airline/:flightCode/:destination', async (req, res) => {
  const flightKey = await flightSuretyData.methods.getFlightKey(
    req.params.airline,
    req.params.flightCode,
    req.params.destination
    ).call()

  const oracleResponse = await flightSuretyApp.methods.oracleResponses(flightKey).call()
  res.send(oracleResponse)
})

export default app;


