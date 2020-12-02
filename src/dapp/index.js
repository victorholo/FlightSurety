
import DOM from './dom';
import Contract from './contract';
import './flightsurety.css';
import axios from 'axios';

(async () => {

    let result = null;

    let contract = new Contract('localhost', () => {

        // Read transaction
        contract.isOperational(async (error, result) => {
            console.log(error, result);
            display('Operational Status', 'Check if contract is operational', [{ label: 'Operational Status', error: error, value: result }]);
            if (result) {

                axios.get(`http://localhost:3000/api/getRegisteredFlights`)
                    .then(res => {
                        displayFlightOptions(res.data);
                    });
            }
        });

        // User-submitted transaction
        DOM.elid('submit-oracle').addEventListener('click', () => {
            let flight = DOM.elid('flight-number').value;
            // Write transaction
            axios.get(`http://localhost:3000/api/fetchFlight?flight=${flight}`)
                .then(function (response) {
                    DOM.appendText(DOM.elid('fetch-response'), JSON.stringify(response.data));
                });
        })
    });
})();


function displayFlightOptions(flights) {
    let select = DOM.elid("flight-number");
    for (let i = 0; i < flights.length; i++) {
        let opt = document.createElement("option");
        opt.value = flights[i];
        opt.textContent = flights[i];
        select.appendChild(opt);
    }
}

function display(title, description, results) {
    let displayDiv = DOM.elid("display-wrapper");
    let section = DOM.section();
    section.appendChild(DOM.h2(title));
    section.appendChild(DOM.h5(description));
    results.map((result) => {
        let row = section.appendChild(DOM.div({ className: 'row' }));
        row.appendChild(DOM.div({ className: 'col-sm-4 field' }, result.label));
        row.appendChild(DOM.div({ className: 'col-sm-8 field-value' }, result.error ? String(result.error) : String(result.value)));
        section.appendChild(row);
    })
    displayDiv.append(section);

}







