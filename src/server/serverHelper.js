
import FlightSuretyApp from '../../build/contracts/FlightSuretyApp.json'
import FlightSuretyData from '../../build/contracts/FlightSuretyData.json'
import Config from './config.json'
import Web3 from 'web3'
require('babel-polyfill')


let config = Config['localhost'];
let web3 = new Web3(new Web3.providers.WebsocketProvider(config.url.replace('http', 'ws')));
web3.eth.defaultAccount = web3.eth.accounts[0];

const flightSuretyApp = new web3.eth.Contract(FlightSuretyApp.abi, config.appAddress);
const flightSuretyData = new web3.eth.Contract(FlightSuretyData.abi, config.dataAddress);


export const oracleServer = {
    STATES : {
      0 : "STATUS_CODE_UNKNOWN",
      10: "STATUS_CODE_ON_TIME",
      20: "STATUS_CODE_LATE_AIRLINE",
      30: "STATUS_CODE_LATE_WEATHER",
      40: "STATUS_CODE_LATE_TECHNICAL",
      50: "STATUS_CODE_LATE_OTHER"
    },
    ORACLES : [],
    FLIGHTS : [],

  
    init: async function (numberOracles) {
        flightSuretyApp.events.registeredOracles()
        .on('data', log => {
            const { event, returnValues: { indexes } } = log
            console.log(`${event}: indexes ${indexes[0]} ${indexes[1]} ${indexes[2]}`)
        })
        .on('error', error => { console.log(error) })
  
        flightSuretyData.events.newAirlineRegistered()
        .on('data', log => {
            const { returnValues: { newAirline, airlineReferral } } = log
            console.log(`${airlineReferral} registered ${newAirline}`)
        })
        .on('error', error => { console.log(error) })
  
        flightSuretyApp.events.registeredFlight()
        .on('data', async log => {
            const {
                event,
                returnValues: { airlineAddress,  flightCode, destination,  departureTime }
            } = log
            console.log(`${event}: ${airlineAddress} with ${flightCode} to ${destination} departing ${departureTime}`)
  
            const indexFlightKeys = await flightSuretyData.methods.totalFlightKeys().call()
            const flightKey = await flightSuretyData.methods.flightKeys(indexFlightKeys).call()
            const flight = await flightSuretyData.methods.flights(flightKey).call()
            const totalFlightKeys = await flightSuretyData.methods.totalFlightKeys.call()
            for (let i= 0; i < totalFlightKeys; i++) {
                delete flight[i]
            }
            this.flights.push({
                index: indexFlightKeys,
                flightKey: flightKey,
                flight: flight
            })
        })
        .on('error', error => { console.log(error) })
  
        flightSuretyApp.events.OracleRequest()
        .on('error', error => { console.log(error) })
        .on('data', async log => {
            const {
                event,
                returnValues: { index, airline, flightCode, departureTime }
            } = log
  
            console.log(`${event}: index ${index}, airline ${airline} with flightCode ${flightCode}, to the destination: ${destination} at departureTime: ${departureTime}`)
            await this.submitResponses(flight, destination, departureTime)
        })
  
        flightSuretyApp.events.OracleReport()
        .on('data', log => {
            const {
                event, 
                returnValues: { airline, flightCode, destination, departureTime, statusCode }
            } = log
            console.log(`${event}: airline ${airline} with flight ${flightCode}, to ${destination}, departureTime ${departureTime}, status ${this.STATES[statusCode]}`)
        })
  
        flightSuretyApp.events.FlightStatusInfo()
        .on('data', log => {
            const {
                event,
                returnValues: { airline, flightCode, destination, departureTime, statusCode }
            } = log
            console.log(`${event}: airline ${airline} with flight ${flightCode}, to ${destination}, with departure at ${departureTime}, status ${this.STATES[statusCode]}`)
        })
        .on('error', error => { console.log(error) })
    
        flightSuretyApp.events.processedFlightStatus()
        .on('data', log => {
            const { event, returnValues: { destination, flightCode, departureTime, statusCode} } = log
            console.log(`${event}: Destination ${destination} with ${flightCode}, departureTime ${departureTime}, status ${this.STATES[statusCode]}`)
        })
  
        flightSuretyData.events.receivedRegistrationFee()
        .on('data', log => {
            const { returnValues: { fundAddress } } = log
            console.log(`${fundAddress} provided funding`)
        })
        .on('error', error => console.log(error))
  
        flightSuretyApp.events.paidInsurance()
        .on('data', log => {
            const { event, returnValues: { customer} } = log
            console.log(`${event} from ${customer}`)
        })
  
        flightSuretyData.events.creditInsurance()
        .on('data', log => {
            const { event, returnValues: { payment, customer } } = log
            console.log(`${event} ${customer}  got  creditInsurance for ${payment}`)
        })
  
        await flightSuretyData.methods.authorizeCaller(flightSuretyApp._address)
        this.oracles = await web3.eth.getAccounts()
        const REGISTRATION_FEE = await flightSuretyApp.methods.REGISTRATION_FEE().call()
        // Oracle registration
        this.oracles.forEach(async account => {
            try {
            await flightSuretyApp.methods.registerOracle().send({
                from: account,
                value: REGISTRATION_FEE,
                gas: 4712388,
                gasPrice: 100000000000
            })
            } catch (error) {
            console.log(error.message)
            }
        })
        // Updating and storing flights
        this.updateFlights()
    },

    updateFlights: async function () {
        this.flights = []
        try {
          const indexFlightKeys = await flightSuretyData.methods.totalFlightKeys().call()
          for (let i = 0; i < indexFlightKeys + 1; i++) {
            const key = await flightSuretyData.methods.totalFlightKeys(i).call()
            const flight = await flightSuretyData.methods.flights(key).call()
            for (let j = 0; j < 9; j++) {
              delete flight[j]
            }
            // as unique key, an index is added and will be displayed in the front end form (instead of displaying the hash key)
            this.flights.push({
              index: i,
              key: key,
              flight: flight
            })
          }
        } catch (error) {
          console.log('No flights to add')
        }
      },
    submitResponses: async function (flight, destination, departureTime) {
      this.oracles.forEach(async oracle => {
        // random number out of [10, 20, 30, 40, 50]
        const statusCode = (Math.floor(Math.random() * 5) + 1) * 10
        // get indexes
        const oracleIndexes = await flightSuretyApp.methods.getMyIndexes().call({ from: oracle })
        oracleIndexes.forEach(async index => {
          try {
            await flightSuretyApp.methods.submitOracleResponse(
              index,
              flight,
              destination,
              departureTime,
              statusCode
            ).send({ from: oracle })
          } catch (error) {
            console.log(error.message)
          }
        })
      })
    },
  }
