import FlightSuretyApp from '../../build/contracts/FlightSuretyApp.json';
import FlightSuretyData from '../../build/contracts/FlightSuretyData.json';
import Config from './config.json';
import Web3 from 'web3';

export default class Contract {
    constructor(network, callback) {
        let config = Config[network];
        if (window.ethereum) {
            this.web3 = new Web3(window.ethereum)
            try {
                window.ethereum.enable()
                } catch (e) {
                console.error('Trying to connect Web3, most likely user denied usage:  ${e}')
                }
        } else if (window.web3) {
            this.web3 = new Web3(web3.currentProvider)
        } else {
            this.web3 = new Web3(new Web3.providers.HttpProvider(config.url))
        }
        this.flightSuretyApp = new this.web3.eth.Contract(FlightSuretyApp.abi, config.appAddress);
        this.flightSuretyData = new this.web3.eth.Contract(FlightSuretyData.abi, config.dataAddress);
        this.initialize(callback);
        this.owner = null;
        this.airlines = [];
        this.passengers = [];
    }

    initialize(callback) {
        this.web3.eth.getAccounts((error, accts) => {
            try {
                this.owner = accts[0];
                this.genesisAirline = accts[1]
                callback();
            } catch(e){
                console.log(`Error initialiazing contract.js with ${e}`)
            }
        });
    }

    isOperational(callback) {
       let self = this;
       self.flightSuretyApp.methods
            .isOperational()
            .call({ from: self.owner}, callback);
    }

    isAuthorizedCaller(flight, callback) {
        let self = this;
        try {
            self.flightSuretyData.methods
            .isAuthorizedCaller(self.owner)  
            .call({ from: self.owner}, callback);
  
        } catch (e) {
            console.log(`Error isAuthorizedCaller in contract.js with ${e}`)
        }
    }
  
    async fetchFlightStatus(airline, flightCode, departureTime) {
        let self = this;
        try {
        const key = await self.flightSuretyApp.methods
                    .fetchFlightStatus(airline, flightCode, departureTime)
                    .send({ from: self.owner,
                            gas: 2000000,
                            gasPrice: '100000'})
                    .then(key => {return key});
        } catch(e){
            console.log(`Error fetchFlightStatus contract.js with ${e}`)   
        }
    }
    
    async authorizeCaller(address){
        try {
            await this.flightSuretyData.methods
                .authorizeCaller(address)
                .send({ from: this.owner,
                    gas: 2000000,
                    gasPrice: '10000000000000'
                })
                return {
                    result: 'sucessfully authorized caller',
                    error: ''
                }
        } catch (error) {
            return {
                    result: 'authorize caller denied',
              error: error
            }
        }
    }

    async fundAndRegisterAirline(fee, airline){
        try{   
            await this.flightSuretyApp.methods
            .fund()
            .send({
                from: this.owner,
                gas: 2000000,
                gasPrice: 100000,
                value: this.web3.utils.toWei(fee, 'ether')
            });
            await this.flightSuretyApp.methods
                .registerAirline(newAirline)
                .send({ from: this.owner,
                        gas: 2000000,
                        gasPrice: 100000
                })
            const referral = await this.flightSuretyApp.methods
                .referralsMissing(airline)
                .call()
            return {
                address: this.owner,
                votes: referral,
                fee: fee
            }
        } catch (error) {
            return {
                error: error
            }
        }
    }

    async registerFlight (
        flightCode,
        origin,
        destination,
        departureTime,
        ticketFee,
        airlineAddress ) {
        try {
            const priceWei = this.web3.utils.toWei(ticketFee.toString(), 'ether')
          await this.flightSuretyApp.methods
            .registerFlight(0,flightCode, origin, destination, departureTime, priceWei)
            .send({ from: this.owner,
                    gas: 2000000,
                    gasPrice: 100000
                })
            const flightKey = await this.flightSuretyData.methods.getFlightIdentifier(airline,flightCode,departureTime).call({ from: this.owner})
            return {
                result: 'Succesfully registered flight',
                error: ''
            }
        } catch (error) {
            return {
                flightKey: 'Unable to register flight',
                error: error
            }
        }
    }

    async getFlightTicketAndBuyInsurance(airline, flightCode, departureTime, customerAddress, payment) {
        const pay = this.web3.utils.toWei(payment.toString(), 'ether')
        try {
            await this.flightSuretyApp.methods
                .bookTicketAndBuyInsurance(airline, flightCode, departureTime,customerAddress, pay)
                .send({
                from: this.owner,
                gas: 2000000,
                gasPrice: 100000,
                value: pay
                })
            return { customer: this.owner }
        } catch (error) {
            console.log(error)
            return {
                error: error
            }
        }
    }

    async payInsuranceToCustomer () {
        await this.flightSuretyApp.methods
            .payInsurance()
            .send({ from: this.owner,
                gas: 2000000,
                gasPrice: 100000,})
      }
}