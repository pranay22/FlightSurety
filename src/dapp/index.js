
import DOM from './dom';
import Contract from './contract';
import './flightsurety.css';


(async() => {

    let result = null;

    let contract = new Contract('localhost', () => {

        // Read transaction
        contract.isOperational((error, result) => {
            console.log(error,result);
            display('Operational Status', 'Check if contract is operational', [ { label: 'Operational Status', error: error, value: result} ]);
        });

        contract.isAuthorizedCaller((error,result) => {
            display('Authorize contract owner', 'Check authorization status', [{label: 'Contract Authorization status', error: error, value: result }])

        // User-submitted transaction
        DOM.elid('submit-oracle').addEventListener('click', async () => {
            let airline = DOM.elid('input-oracle-airline').value;
            let flightCode = DOM.elid('input-oracle-flightCode').value;  
            let departureTime = DOM.elid('input-oracle-departureTime').value; 
            departureTime = new Date(departureTime).getTime()

           const key = await contract.fetchFlightStatus(airline, flightCode, departureTime);
           console.log(key) //todo
        })
        DOM.elid('btn-register-airline').addEventListener('click', async () => {
            const newAirline = DOM.elid('input-reg-airline-addr').value;
            console.log(newAirline);
            let fee = DOM.elid('input-fund').value;
            console.log(fee);
            const { address, votes, contractFee, error } = await contract.fundAndRegisterAirline(fee,newAirline)
            console.log(address);
            console.log(votes);
            console.log(error);
            display(
              `Airline ${address}`,
              'Register Airline', [{
                label: newAirline,
                error: error,
                value: `The fee is ${contractFee} and ${votes} more vote(s) required`
              }]
            )
        })
        DOM.elid('btn-register-flight').addEventListener('click', async () => {
        const flightCode = DOM.elid('input-flight-flightCode').value
        const origin = DOM.elid('input-flight-origin').value            
        const destination = DOM.elid('input-flight-destination').value
        const departureTime = new Date(DOM.elid('input-flight-departureTime').value).getTime()
        const ticketFee = DOM.elid('input-flight-ticketFee').value
        await contract.registerFlight(
            flightCode,
            origin,
            destination,
            departureTime,
            ticketFee
            )    
        })
        DOM.elid('btn-buy-flight').addEventListener('click', async () => {
            const airlineAddress = DOM.elid('input-buy-flight-airline-address').value
            const flightCode = DOM.elid('input-buy-flight-flightCode').value
            const departureTime = new Date(DOM.elid('input-buy-flight-departureTime').value).getTime()
            const customerAddress = DOM.elid('input-buy-flight-customer-address').value
            const payment = DOM.elid('input-buy-flight-payment').value

            const { customer, error } = await contract.getFlightTicketAndBuyInsurance(
                airlineAddress,
                flightCode,
                departureTime,
                customerAddress,
                payment)
                display(
                  `Customer ${customer}`,
                  'Bought flight and insurance',
                  [{
                    label: `Flight with code ${flightCode} departures at ${departureTime}`,
                    error: error,
                    value: `payment: ${payment} ETH`
                  }]
                )
        })
        DOM.elid('btn-pay-insurance').addEventListener('click', () => {
            try {
              contract.payInsuranceToCustomer()
            } catch (error) {
              console.log(error.message)
            }
        })
    });
})();


function display(title, description, results) {
    let displayDiv = DOM.elid("display-wrapper");
    let section = DOM.section();
    section.appendChild(DOM.h2(title));
    section.appendChild(DOM.h5(description));
    results.map((result) => {
        let row = section.appendChild(DOM.div({className:'row'}));
        row.appendChild(DOM.div({className: 'col-sm-4 field'}, result.label));
        row.appendChild(DOM.div({className: 'col-sm-8 field-value'}, result.error ? String(result.error) : String(result.value)));
        section.appendChild(row);
    })
    displayDiv.append(section);

    DOM.elid('btn-auth-customer').addEventListener('click', async () => {
        let inputAuthCustomer = DOM.elid('input-auth-customer').value
        const { result, error } = await contract.authorizeCaller(inputAuthCustomer)
        console.log(`Result input auth customer: ${result}`);
        console.log(`Error input auth customer: ${error}`);     
      })
}







