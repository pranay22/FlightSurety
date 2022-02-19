
var Test = require('../config/testConfig.js');
var BigNumber = require('bignumber.js');
const truffleAssert = require('truffle-assertions');

contract('Flight Surety Tests', async (accounts) => {

  var config;
  //Fund 
  const minPayment = web3.utils.toWei('10', 'ether');

  //FLight
  const statusCode = 0;
  const flightCode = "BRAARG";
  const origin ="BRASIL";
  const destination = "ARGENTINA";
  const departureTime = Math.floor(Date.now() / 100000) + 10000000000000;
  const ticketFee = web3.utils.toWei('1', 'ether');
  const fee = web3.utils.toWei('2', 'ether') ;

  before('setup contract', async () => {
    config = await Test.Config(accounts);
    await config.flightSuretyData.authorizeCaller(config.flightSuretyApp.address);
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
      try 
      {
          await config.flightSuretyData.setOperatingStatus(false, { from: config.testAddresses[2] });
      }
      catch(e) {
          accessDenied = true;
      }
      assert.equal(accessDenied, true, "Access not restricted to Contract Owner");
            
  });

  it(`(multiparty) can allow access to setOperatingStatus() for Contract Owner account`, async function () {

      // Ensure that access is allowed for Contract Owner account
      let accessDenied = false;
      try 
      {
          await config.flightSuretyData.setOperatingStatus(false);
      }
      catch(e) {
          accessDenied = true;
      }
      assert.equal(accessDenied, false, "Access not restricted to Contract Owner");
      
  });

  it('Register genesis airline', async () => {
    let result = await config.flightSuretyData.isAirline(config.firstAirline);
    assert.equal(result, true);
  });

  it(`(multiparty) can block access to functions using requireIsOperational when operating status is false`, async function () {

      await config.flightSuretyData.setOperatingStatus(false);

      let reverted = false;
      try 
      {
          await config.flightSurety.setTestingMode(true);
      }
      catch(e) {
          reverted = true;
      }
      assert.equal(reverted, true, "Access not blocked for requireIsOperational");      

      // Set it back for other tests to work
      await config.flightSuretyData.setOperatingStatus(true);

  });

  it('(airline) cannot register an Airline using registerAirline() if it is not funded', async () => {
    
    // ARRANGE
    let newAirline = accounts[2];

    // ACT
    try {
        await config.flightSuretyApp.registerAirline("newAirline", newAirline, {from: config.firstAirline});
    }
    catch(e) {

    }
    let result = await config.flightSuretyData.isAirline.call(newAirline); 

    // ASSERT
    assert.equal(result, false, "Airline should not be able to register another airline if it hasn't provided funding");

  });

  it('airline funded', async () => {

    const initialBalance = await web3.eth.getBalance(config.flightSuretyData.address);
    const airlineRegistered = await config.flightSuretyData.isAirline(config.firstAirline);

    try{
      await config.flightSuretyApp.fund({ from: config.firstAirline, value: minPayment });
    }
    catch (error) {
      console.log(error.message)
    }

    const balanceFund = await web3.eth.getBalance(config.flightSuretyData.address)   
    //console.log(`balance fund ${balanceFund}`);
    assert.equal(balanceFund, minPayment)
  })

  it('function call is made when multi-party, when Airline have paid registrationFee, but user 5 will fail', async () => {

    // ARRANGE 
    let user2 = accounts[2];
    let user3 = accounts[3];
    let user4 = accounts[4];
    let user5 = accounts[5];

    await config.flightSuretyApp.fund({from: user2, value: minPayment});
    await config.flightSuretyApp.registerAirline("newAirline2",user2, {from: config.firstAirline});
    await config.flightSuretyApp.fund({from: user3, value: minPayment});
    await config.flightSuretyApp.registerAirline("newAirline3",user3, {from: config.firstAirline});
    await config.flightSuretyApp.fund({from: user4, value: minPayment});
    await config.flightSuretyApp.registerAirline("newAirline4",user4, {from: config.firstAirline});

    // ASSERT
    //multisign
    assert.equal(await config.flightSuretyData.isAirline.call(user2), true, "Multi-party call succeed");
    assert.equal(await config.flightSuretyData.isAirline.call(user3), true, "Multi-party call succeed");
    assert.equal(await config.flightSuretyData.isAirline.call(user4), true, "Multi-party call succeed");
    assert.equal(await config.flightSuretyData.isAirline.call(user5), false, "Multi-party call failed");

  });

  it('function call is made when multi-party, when Airline have paid registrationFee, but user 5 will suceed', async () => {

    // ARRANGE 
    let user2 = accounts[2];
    let user3 = accounts[3];
    let user4 = accounts[4];
    let user5 = accounts[5];

    await config.flightSuretyApp.fund({from: user2, value: minPayment});
    await config.flightSuretyApp.registerAirline("newAirline2",user2, {from: config.firstAirline});
    await config.flightSuretyApp.fund({from: user3, value: minPayment});
    await config.flightSuretyApp.registerAirline("newAirline3",user3, {from: config.firstAirline});
    await config.flightSuretyApp.fund({from: user4, value: minPayment});
    await config.flightSuretyApp.registerAirline("newAirline4",user4, {from: config.firstAirline});

    await config.flightSuretyApp.fund({from: user5, value: minPayment});
    await config.flightSuretyApp.registerAirline("newAirline5",user5, {from: user4});
    await config.flightSuretyApp.registerAirline("newAirline5",user5, {from: user2});
    await config.flightSuretyApp.registerAirline("newAirline5",user5, {from: user3});

    // ASSERT
    //multisign
    assert.equal(await config.flightSuretyData.isAirline.call(user2), true, "Multi-party call succeed");
    assert.equal(await config.flightSuretyData.isAirline.call(user3), true, "Multi-party call succeed");
    assert.equal(await config.flightSuretyData.isAirline.call(user4), true, "Multi-party call succeed");
    assert.equal(await config.flightSuretyData.isAirline.call(user5), true, "Multi-party call succeed");

  });

  it('Register flight', async () => {
    const registerFlight = await config.flightSuretyApp.registerFlight(
      statusCode,
      flightCode,
      origin,
      destination,
      departureTime,
      ticketFee,  
      { from: config.firstAirline});

    truffleAssert.eventEmitted(registerFlight, 'registeredFlight', ev => {
      return ev.flightCode === "BRAARG"
    });
  });

  it('Customer buys ticket and insurance', async () => {
      await config.flightSuretyApp.getFlightTicketAndBuyInsurance(
      config.firstAirline,  
      flightCode,
      departureTime,
      accounts[6],
      fee,
      {
        from: accounts[6],
        value: fee 
      }
    )  
    assert(await config.flightSuretyData.checkBoughtFlightTicket(config.firstAirline,flightCode, departureTime, accounts[6]));
  })

});
