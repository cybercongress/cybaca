const { getRandomString, getRandomInt } = require('./helpers/helpers')
const { latest, duration, increase, increaseTo } = require('openzeppelin-solidity/test/helpers/time');

const chai = require("chai");
const BN = require("bn.js");
const bnChai = require("bn-chai");
const expect = chai.expect;

chai.use(bnChai(BN));
chai.use(require('chai-as-promised'))
chai.should();

const Cybercon = artifacts.require("Cybercon");

web3.currentProvider.sendAsync = web3.currentProvider.send; // TODO: fix this

contract("Cybercon", (accounts) => {
    
    let cybercon;
    let deployed;
    let ticketsFunds = new BN('0');
    let speakersDeposits = new BN('0');
    let ticketsBids = [];
    
    function calculatedPrice(currentTime) {
        let passed = currentTime - deployed;
        let mul = new BN('3000000000000000');
        let currentDiscount = (new BN(Math.round(passed/3600))).mul(mul);
        if ((INITIAL_PRICE.sub(MINIMAL_PRICE)).cmp(currentDiscount)) {
            return INITIAL_PRICE.sub(currentDiscount);
        } else { return MINIMAL_PRICE; }
    }
    
    function calculatedSpeakersShares(time) {
        let timeDiff = (new BN(time.toString())).sub(new BN(deployed.toString()));
        // console.log("Time diff: ", timeDiff.toString(10));
        // let mul1 = timeDiff.imul(new BN('100')).idiv((new BN(CHECKIN_START.toString())).isub(new BN(deployed.toString())));
        let totalTime = (new BN(CHECKIN_START.toString())).sub(new BN(deployed.toString()));
        // console.log("Total time: ", totalTime.toString(10));
        let timeDiff100 = new BN(timeDiff.mul(new BN('100')));
        // console.log("Time Diff 100: ", timeDiff100.toString(10));
        let mul = timeDiff100.div(totalTime);
        // console.log("Mul: ", mul.toString(10));
        let divShares = (new BN(SPEAKERS_START_SHARES.toString())).sub(new BN(SPEAKERS_END_SHARES.toString()));
        // console.log("Div Shares: ", divShares.toString(10));
        let divSharesMul = divShares.mul(mul);
        // console.log("Div Shares Mul: ", divSharesMul.toString(10));
        let calcCurrentSharesAdd = divSharesMul.div(new BN('100'));
        // console.log("Calc Add Shares: ", calcCurrentSharesAdd.toString(10));
        let speakersShares = calcCurrentSharesAdd.add(new BN(SPEAKERS_END_SHARES.toString()));
        // console.log("Calculated Speakers Shares: ", speakersShares.toString(10));
        return speakersShares;
    }
    
    const CYBERCON_ORGANIZER = accounts[0];
    const RANDOM_WALKER = accounts[249];
    
    const CYBERCON_NAME = "Cybercon0";
    const CYBERCON_SYMBOL = "CYBERCON0";
    const CYBERCON_PLACE = "Korpus 8";
    
    const TICKETS_AMOUNT = 200;
    const SPEAKERS_SLOTS = 8;
    
    // const ORGANIZERS_START_SHARES = 80;
    const SPEAKERS_START_SHARES = 80;
    const SPEAKERS_END_SHARES = 20;
    
    const INITIAL_PRICE = new BN('1500000000000000000');
    const MINIMAL_PRICE = new BN('300000000000000000');
    
    const EXPECTED_START = 1543611600;
    const CHECKIN_START = 1544767200;
    const CHECKIN_END = 1544792400;
    const DISTRIBUTION_START = 1544796000;
    
    before(async () => {
        await increaseTo(EXPECTED_START);
        cybercon = await Cybercon.new({ from: CYBERCON_ORGANIZER });
        deployed = await latest();
        console.log("cybercon0 address: ", cybercon.address);
        console.log("deployed time: ", deployed);
    })
    
    describe("when deployed", () => {
        it("name should equeal", async() => {
            (await cybercon.name()).should.equal(CYBERCON_NAME);
        });
        
        it("token symbol should equeal", async() => {
            (await cybercon.symbol()).should.equal(CYBERCON_SYMBOL);
        });
        
        it("checkin start time should equal", async() => {
            (await cybercon.getEventStartTime()).toNumber().should.equal(CHECKIN_START);
        });
        
        it("checkin end time should equal", async() => {
            (await cybercon.getEventEndTime()).toNumber().should.equal(CHECKIN_END);
        });
        
        it("distribution start time time should equal", async() => {
            (await cybercon.getDistributionTime()).toNumber().should.equal(DISTRIBUTION_START);
        });
        
        it("initial organizers and speakers shares should be equal", async() => {
            // (await cybercon.getOrganizersShares()).toNumber().should.equal(ORGANIZERS_START_SHARES);
            // (await cybercon.getSpeakersShares()).toNumber().should.equal(SPEAKERS_START_SHARES);
            // (ORGANIZERS_START_SHARES + SPEAKERS_START_SHARES).should.be.equal(100);
        });
        
        it("tickets amount should equal", async() => {
            (await cybercon.getTicketsAmount()).toNumber().should.equal(TICKETS_AMOUNT);
        });
        
        it("speakers slots should equeal", async() => {
            (await cybercon.getSpeakersSlots()).toNumber().should.equal(SPEAKERS_SLOTS);
        });
        
        it("place symbol should equeal", async() => {
            (await cybercon.getPlace()).should.equal(CYBERCON_PLACE);
        });
        
        it("initial price should be equal", async() => {
            let currentPrice = await cybercon.getCurrentPrice();
            expect(currentPrice).to.eq.BN(calculatedPrice(await latest()));
        });
    })
    
    describe("when auction started", () => {
        it("should start dutch auction, distribute first half of tickets", async() => {
            for (var i = 0; i < TICKETS_AMOUNT/2; i++){
            // for (var i = 0; i < 10; i++){
                let bid = calculatedPrice(await latest());
                ticketsBids.push(bid);
                expect(bid).to.eq.BN(await cybercon.getCurrentPrice());
                await cybercon.buyTicket({ from: accounts[i], value: bid }).should.be.fulfilled;                
                ticketsFunds.iadd(bid);
        
                let bidFromContract = await cybercon.getBidForTicket(i);
                expect(bidFromContract[0]).to.eq.BN(bid);
                bidFromContract[1].should.be.equal(accounts[i]);
                await cybercon.buyTicket({ from: accounts[i], value: bid }).should.be.rejected;
        
                await increase(3600);
            }
        
            expect(await web3.eth.getBalance(cybercon.address)).to.eq.BN(ticketsFunds);
            expect(await cybercon.getTicketsFunds()).to.eq.BN(ticketsFunds);
        });
    
        it("should apply speakers", async() => {
            for (var i = 200; i < 208; i++){
                let talk = {
                    sn: getRandomString(32),
                    ds: getRandomString(128),
                    dt: getRandomString(256),
                    du: getRandomInt(900, 3600),
                    va: (new BN(getRandomInt(1000, 5000).toString())).mul(new BN('1000000000000000'))
                }
                await cybercon.applyForTalk(talk.sn, talk.ds, talk.dt, talk.du,
                    {
                        from: accounts[i],
                        value: talk.va
                    }
                ).should.be.fulfilled;
                speakersDeposits.iadd(talk.va);
        
                let talkFromContract = await cybercon.getTalkById(i-200);
                talkFromContract[0].should.be.equal(talk.sn);
                talkFromContract[1].should.be.equal(talk.ds);
                talkFromContract[2].should.be.equal(talk.dt);
                talkFromContract[3].toNumber().should.be.equal(talk.du);
                expect(talkFromContract[4]).to.eq.BN(talk.va);
                talkFromContract[5].should.be.equal(accounts[i]);
        
                await increase(900);
            }
        
            expect(await web3.eth.getBalance(cybercon.address)).to.eq.BN(ticketsFunds.add(speakersDeposits));
            expect(await cybercon.getSpeakersDeposits()).to.eq.BN(speakersDeposits);
            (await cybercon.totalSupply()).toNumber().should.be.equal(100);
        });
    
        it("should not apply more more than 8 speakers", async() => {
            for (var i = 209; i < 211; i++){
                let talk = {
                    sn: getRandomString(32),
                    ds: getRandomString(128),
                    dt: getRandomString(256),
                    du: getRandomInt(900, 3600),
                    va: (new BN(getRandomInt(1000, 5000).toString())).mul(new BN('1000000000000000'))
                }
                await cybercon.applyForTalk(talk.sn, talk.ds, talk.dt, talk.du,
                    {
                        from: accounts[i],
                        value: talk.va
                    }
                ).should.be.rejected;
            }
        });
    
        it("shoud continuon the dutch auction, distribute second half of tickets", async() => {
            for (var i = TICKETS_AMOUNT/2; i < TICKETS_AMOUNT; i++){                
                let bid = await cybercon.getCurrentPrice()
                ticketsBids.push(bid);
                await cybercon.buyTicket({ from: accounts[i], value: bid }).should.be.fulfilled;                
                ticketsFunds.iadd(bid);
        
                let bidFromContract = await cybercon.getBidForTicket(i);
                expect(bidFromContract[0]).to.eq.BN(bid);
                bidFromContract[1].should.be.equal(accounts[i]);
                await cybercon.buyTicket({ from: accounts[i], value: bid }).should.be.rejected;
        
                await increase(1800);
            }
        
            expect(await cybercon.getTicketsFunds()).to.eq.BN(ticketsFunds);
            expect(await web3.eth.getBalance(cybercon.address)).to.eq.BN(ticketsFunds.add(speakersDeposits));
            expect(ticketsBids.slice(-1)[0]).to.eq.BN(await cybercon.getEndPrice());
            (await cybercon.getTicketsAmount()).toNumber().should.be.equal(0);
            (await cybercon.totalSupply()).toNumber().should.be.equal(200);
        });
    })
    
    describe("when conference starts", () => {
        it("shoud checkin speaksers, send tokens for them", async() => {
            await increaseTo(CHECKIN_START);
            for (var i = 200; i < 208; i++){
                await increase(1800);
                await cybercon.checkinSpeaker(i-200, { from: CYBERCON_ORGANIZER }).should.be.fulfilled;
                let talkFromContract = await cybercon.getTalkById(i-200);
                talkFromContract[7].should.be.equal(true);
            }
            (await cybercon.totalSupply()).toNumber().should.be.equal(208);
        })
    })
    
    describe("when distribution starts", () => {
        
        it("should correctly distribute overbids", async() => {
            await increaseTo(DISTRIBUTION_START)
            let membersBalancesBefore = [];
            // let membersBalancesAfter = [];
            let endPrice = new BN(await cybercon.getEndPrice());
            let walkerBalanceBefore = (new BN(await web3.eth.getBalance(RANDOM_WALKER)));
            for (var i = 0; i < TICKETS_AMOUNT; i++){
                membersBalancesBefore.push(new BN(await web3.eth.getBalance(accounts[i])));
            }
            await cybercon.distributeBids({ from: RANDOM_WALKER }).should.be.fulfilled;
            for (var i = 0; i < TICKETS_AMOUNT; i++){
                let balanceAfter = new BN(await web3.eth.getBalance(accounts[i]));
                let diff = new BN(balanceAfter.sub(membersBalancesBefore[i]));
                let overbid = new BN(ticketsBids[i].sub(endPrice));
                expect(diff).to.eq.BN(overbid);
            }
            let walkerBalanceAfter = (new BN(await web3.eth.getBalance(RANDOM_WALKER)));
            expect(walkerBalanceAfter.sub(walkerBalanceBefore)).to.gt.BN(new BN('900000000000000000')); // gas payed by walker
        })
        
        it("should correctly distribute rewards", async() => {
            let walkerBalanceBefore = (new BN(await web3.eth.getBalance(RANDOM_WALKER)));
            let organizerBalance = new BN(await web3.eth.getBalance(CYBERCON_ORGANIZER));
            let speakersBalances = [];
            for (var i = 200; i < 208; i++){
                speakersBalances.push(new BN(await web3.eth.getBalance(accounts[i])));
            }
            let calculatedShares = calculatedSpeakersShares(await cybercon.getAuctionEndTime());
            console.log("_______________");
            console.log("Calculated Speakers Shares: ", calculatedShares.toString(10));
            console.log("Actual Speakers shares: ", (await cybercon.getSpeakersShares()).toString());
            console.log("_______________");
            expect(await cybercon.getSpeakersShares()).to.eq.BN(calculatedShares);
            
            let endPrice = new BN(await cybercon.getEndPrice());
            let valueFromTicketsForReward = endPrice.mul(new BN(TICKETS_AMOUNT));
            
            await cybercon.distributeRewards({ from: RANDOM_WALKER }).should.be.fulfilled;
            let valuePerSpeaker = (valueFromTicketsForReward.mul(calculatedShares).div(new BN('100'))).div(new BN(SPEAKERS_SLOTS.toString()));
            for (var i = 200; i < 208; i++){
                let talkFromContract = await cybercon.getTalkById(i-200);
                let speakerBalanceAfter = new BN(await web3.eth.getBalance(accounts[i]));
                console.log("Speaker's talk ID: ", (i-200));
                console.log("Value for speaker's from tickets: ", web3.utils.fromWei(valuePerSpeaker, 'ether'));
                console.log("Deposit of speaker's: ", web3.utils.fromWei(talkFromContract[4], 'ether'));
                console.log("Speaker's balance before: ", web3.utils.fromWei(speakersBalances[i-200], 'ether'));
                console.log("Speaker's balance after: ", web3.utils.fromWei(speakerBalanceAfter, 'ether'));
                console.log("_______________");
                let balanceDiff = speakerBalanceAfter.sub(speakersBalances[i-200]);
                let payment = valuePerSpeaker.add(new BN(talkFromContract[4]));
                expect(balanceDiff).to.eq.BN(payment);
            }
            let organizerShares = (new BN('100')).sub(calculatedShares);
            let valueForOrganizer = (valueFromTicketsForReward.mul(organizerShares).div(new BN('100'))).sub(new BN('2000000000000000000'));
            let organizerBalanceAfter = new BN(await web3.eth.getBalance(CYBERCON_ORGANIZER));
            console.log("Value for organizer: ", web3.utils.fromWei(valueForOrganizer, 'ether'));
            console.log("Organizer's balance before: ", web3.utils.fromWei(organizerBalance, 'ether'));
            console.log("Organizer's balance after: ", web3.utils.fromWei(organizerBalanceAfter, 'ether'));
            console.log("Organizer's balance diff: ", web3.utils.fromWei((organizerBalanceAfter.sub(organizerBalance)), 'ether'));
            expect(organizerBalanceAfter.sub(valueForOrganizer)).to.eq.BN(organizerBalance);
            
            let walkerBalanceAfter = (new BN(await web3.eth.getBalance(RANDOM_WALKER)));
            expect(walkerBalanceAfter.sub(walkerBalanceBefore)).to.gt.BN(new BN('900000000000000000')); // gas payed by walker
        })
    })
})