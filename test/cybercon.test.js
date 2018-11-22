const { should, getRandomString, getRandomInt } = require('./helpers/helpers')
const { latest, duration, increase, increaseTo } = require('openzeppelin-solidity/test/helpers/time');

const Cybercon = artifacts.require("Cybercon");

web3.currentProvider.sendAsync = web3.currentProvider.send; // fix this

contract("Cybercon", (accounts) => {
    
    function price(currentTime) {
        let passed = currentTime - deployed;
        let currentDiscount = (Math.round(passed/3600))*3;
        if (currentDiscount < INITIAL_PRICE - MINIMAL_PRICE) {
            return (INITIAL_PRICE - currentDiscount).toString();
        } else { return MINIMAL_PRICE.toString(); }
    }
    
    let cybercon;
    let deployed;
    let ticketsFunds = 0;
    let speakersFunds = 0;
    
    const CYBERCON_ORGANIZER = accounts[0];
    
    const CYBERCON_NAME = "Cybercon0";
    const CYBERCON_SYMBOL = "CYBERCON0";
    const CYBERCON_PLACE = "Korpus 8";
    
    const TICKETS_AMOUNT = 200;
    const SPEAKERS_SLOTS = 8;
    
    const ORGANIZERS_SHARES = 80;
    const SPEAKERS_SHARES = 20;
    
    const INITIAL_PRICE = 1500;
    const MINIMAL_PRICE = 300;
    
    const EXPECTED_START = 1543611600;
    const CHECKIN_START = 1544767200;
    const CHECKIN_END = 1544792400;
    const DISTRIBUTION_START = 1544796000;
    
    before(async () => {
        let currentTime = Math.round((new Date()).getTime() / 1000)
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
        
        it("organizers and speakers shares should equeal", async() => {
            (await cybercon.getOrganizersShares()).toNumber().should.equal(ORGANIZERS_SHARES);
            (await cybercon.getSpeakersShares()).toNumber().should.equal(SPEAKERS_SHARES);
            (SPEAKERS_SHARES + ORGANIZERS_SHARES).should.be.equal(100);
            (ORGANIZERS_SHARES % SPEAKERS_SHARES).should.be.equal(0);
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
            let currentPrice = web3.utils.fromWei(await cybercon.getCurrentPrice(), 'finney');
            let currentTime = (await web3.eth.getBlock("latest")).timestamp;
            currentPrice.should.be.equal(price(currentTime));
        });
    })
    
    describe("when auction started", () => {
        it("should start dutch auction, distribute first half of tickets", async() => {
            for (var i = 0; i < TICKETS_AMOUNT/2; i++){
            // for (var i = 0; i < 10; i++){
                let bid = price(await latest());
                let currentPrice = web3.utils.fromWei(await cybercon.getCurrentPrice(), 'finney');
                await cybercon.buyTicket({ from: accounts[i], value: web3.utils.toWei(bid, 'finney') }).should.be.fulfilled;
                ticketsFunds += parseInt(bid);
                await increase(3600);
                let bidFromContract = await cybercon.getBidForTicket(i);
                (web3.utils.fromWei(bidFromContract[0], 'finney')).should.be.equal(bid.toString());
                bidFromContract[1].should.be.equal(accounts[i]);
                await cybercon.buyTicket({ from: accounts[i], value: web3.utils.toWei(bid, 'finney') }).should.be.rejected;
            }
            let balance = web3.utils.fromWei(await web3.eth.getBalance(cybercon.address), 'finney');
            balance.should.be.equal(ticketsFunds.toString());
        });
        
        it("should apply speakers", async() => {
            for (var i = 200; i < 208; i++){
                let talk = {
                    sn: getRandomString(32),
                    ds: getRandomString(128),
                    dt: getRandomString(256),
                    du: getRandomInt(900, 3600),
                    va: getRandomInt(1000, 5000)
                }
                await cybercon.applyForTalk(talk.sn, talk.ds, talk.dt, talk.du,
                    {
                        from: accounts[i],
                        value: (web3.utils.toWei(talk.va.toString(), 'finney'))
                    }
                ).should.be.fulfilled;
                speakersFunds += talk.va;
                let talkFromContract = await cybercon.getTalkById(i-200);
                talkFromContract[0].should.be.equal(talk.sn);
                talkFromContract[1].should.be.equal(talk.ds);
                talkFromContract[2].should.be.equal(talk.dt);
                talkFromContract[3].toNumber().should.be.equal(talk.du);
                (web3.utils.fromWei(talkFromContract[4], 'finney')).should.be.equal(talk.va.toString());
                talkFromContract[5].should.be.equal(accounts[i]);
            }
            let balance = web3.utils.fromWei(await web3.eth.getBalance(cybercon.address), 'finney');
            balance.should.be.equal((ticketsFunds+speakersFunds).toString());
        });
        
        it("should not apply more more than 8 speakers", async() => {
            for (var i = 209; i < 211; i++){
                let talk = {
                    sn: getRandomString(32),
                    ds: getRandomString(128),
                    dt: getRandomString(256),
                    du: getRandomInt(900, 3600),
                    va: getRandomInt(1000, 5000)
                }
                await cybercon.applyForTalk(talk.sn, talk.ds, talk.dt, talk.du,
                    {
                        from: accounts[i],
                        value: (web3.utils.toWei(talk.va.toString(), 'finney'))
                    }
                ).should.be.rejected;
            }
        });
        
        it("shoud continuon the dutch auction, distribute second half of tickets", async() => {
            for (var i = TICKETS_AMOUNT/2; i < TICKETS_AMOUNT; i++){
                let bid = web3.utils.fromWei(await cybercon.getCurrentPrice(), 'finney'); // move to local calculated
                await cybercon.buyTicket({ from: accounts[i], value: web3.utils.toWei(bid, 'finney') }).should.be.fulfilled;
                ticketsFunds += parseInt(bid);
                await increase(1800);
                let bidFromContract = await cybercon.getBidForTicket(i);
                (web3.utils.fromWei(bidFromContract[0], 'finney')).should.be.equal(bid.toString());
                bidFromContract[1].should.be.equal(accounts[i]);
                await cybercon.buyTicket({ from: accounts[i], value: web3.utils.toWei(bid, 'finney') }).should.be.rejected;
            }
            let balance = web3.utils.fromWei(await web3.eth.getBalance(cybercon.address), 'finney');
            balance.should.be.equal((ticketsFunds+speakersFunds).toString());
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
        it("should correctly distribute profit", async() => {
            await increaseTo(DISTRIBUTION_START)
            let organizerBalance = parseInt(web3.utils.fromWei(await web3.eth.getBalance(CYBERCON_ORGANIZER), 'finney'));
            let speakersBalances = [];
            for (var i = 200; i < 208; i++){
                speakersBalances.push(parseInt(web3.utils.fromWei(await web3.eth.getBalance(accounts[i]), 'finney')));
            }
            await cybercon.distributeProfit({ from: CYBERCON_ORGANIZER }).should.be.fulfilled;
            let valuePerSpeaker = ((ticketsFunds/(ORGANIZERS_SHARES/SPEAKERS_SHARES))+speakersFunds)/8;
            for (var i = 200; i < 208; i++){
                let speakerBalance2 = parseInt(web3.utils.fromWei(await web3.eth.getBalance(accounts[i]), 'finney'));
                // console.log("value per speaker: ", valuePerSpeaker);
                // console.log("speaker before: ", speakersBalances[i-200]);
                // console.log("speaker after: ", speakerBalance2);
                // console.log("_______________");
                // (speakerBalance2-valuePerSpeaker).should.be.equal(speakersBalances[i-200]);
            }
            let valueForOrganizer = (ticketsFunds*ORGANIZERS_SHARES)/(ORGANIZERS_SHARES+SPEAKERS_SHARES);
            let organizerBalance2 = parseInt(web3.utils.fromWei(await web3.eth.getBalance(CYBERCON_ORGANIZER), 'finney'));
            // console.log("value for organizer: ", valueForOrganizer);
            // console.log("organizer before: ", organizerBalance);
            // console.log("organizer after: ", organizerBalance2);
            // (organizerBalance2-valueForOrganizer).should.be.equal(organizerBalance);
        })
    })
})