var Cybercon = artifacts.require("Cybercon");
const Web3 = require('web3');
const web3 = new Web3(new Web3.providers.HttpProvider('http://localhost:7545'));
require('openzeppelin-test-helpers/configure')({ web3: web3 });
const { BN } = require('openzeppelin-test-helpers');

module.exports = async function(deployer) {

	const TALKS_APPLICATION_END = Math.round(Date.now() / 1000) + 2*24*60*60;
	const CHECKIN_START = TALKS_APPLICATION_END + 1*24*60*60;
	const CHECKIN_END = CHECKIN_START + 12*60*60;
	const DISTRIBUTION_START = CHECKIN_END + 1*60*60;

	const INITIAL_PRICE = web3.utils.toWei(new BN(3000), 'finney');
	const MINIMAL_PRICE = web3.utils.toWei(new BN(500), 'finney');
	const BID_BLOCK_DECREASE = web3.utils.toWei(new BN(30), 'szabo');
	const MINIMAL_SPEAKER_DEPOSIT = web3.utils.toWei(new BN(3000), 'finney');

	const CYBERCON_NAME = "cyberc0n";
	const CYBERCON_SYMBOL = "CYBERC0N";
	const CYBERCON_DESCRIPTION = "CYBACA RELEASE";
	const CYBERCON_PLACE = "Andromeda";

	const TICKETS_AMOUNT = 146;
	const SPEAKERS_SLOTS = 24;

	const TIMINGS_SET = [TALKS_APPLICATION_END, CHECKIN_START, CHECKIN_END, DISTRIBUTION_START];
	const ECONOMY_SET = [INITIAL_PRICE, MINIMAL_PRICE, BID_BLOCK_DECREASE, MINIMAL_SPEAKER_DEPOSIT];
	const EVENT_SET = [TICKETS_AMOUNT, SPEAKERS_SLOTS]

	const cybaca = await deployer.deploy(
		Cybercon,
		TIMINGS_SET,
		ECONOMY_SET,
		EVENT_SET,
		CYBERCON_NAME,
		CYBERCON_SYMBOL,
		CYBERCON_DESCRIPTION,
		CYBERCON_PLACE
	);

};
