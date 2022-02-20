
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







