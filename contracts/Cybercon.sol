pragma solidity 0.4.25;

import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/token/ERC721/ERC721Full.sol";
import "openzeppelin-solidity/contracts/utils/ReentrancyGuard.sol";


contract Cybercon is Ownable, ReentrancyGuard, ERC721Full {
    
    using SafeMath for uint256;
    
    enum ApplicationStatus {Applied, Accepted, Declined}
    
    struct Talk {
        string  speakerName;
        string  descSpeaker;
        string  deskTalk;
        uint256 duration;
        uint256 deposit;
        address speakerAddress;
        uint256 appliedAt;
        bool    checkedIn;
        ApplicationStatus status;
    }
    
    struct Bid {
        uint256 value;
        address bidderAddress;
    }
    
    uint256 private auctionStart;
    uint256 private talksApplicationEnd = 1544572800; // const
    uint256 private auctionEnd = 1544767200;
    uint256 private checkinStart = 1544767200; // const
    uint256 private checkinEnd = 1544792400; // const
    uint256 private distributionStart = 1544796000; // const
    // ------------
    uint256 private initialPrice = 1500 finney; // const
    uint256 private minimalPrice = 300 finney; // const
    uint256 private endPrice = 300 finney;
    uint256 private timeframe    = 3600; // const
    uint256 private timeframeDowngrade = 3 finney; // const
    // ------------
    uint256 private ticketsAmount = 200;
    uint256 private speakersSlots = 10; // const
    uint256 private acceptedSpeakersSlots = 0;
    uint256 private speakearsStartShares = 80; // const
    uint256 private speakersEndShares = 20; // const
    // ------------
    uint256 private ticketsFunds = 0;
    uint256 private minimalSpeakerDeposit = 1000 finney; // const
    // ------------
    string private  eventSpace = "Korpus 8"; // const
    
    mapping(address => bool) private membersBidded;
    bool private bidsDistributed = false;
    
    Bid[]   private membersBids;
    Talk[]  private speakersTalks;
    uint256[] private talksGrid;
    uint256[] private workshopsGrid;
    
    event TicketBid(
        uint256 _id,
        address _member,
        uint256 _value
    );
    
    event TalkApplication(
        string  _name,
        address _member,
        uint256 _value
    );
    
    constructor() ERC721Full("Cybercon0", "CYBERCON0")
        public
    {
        auctionStart = block.timestamp;
    }
    
    function() external {}
    
    modifier beforeApplicationStop() {
        require(block.timestamp < talksApplicationEnd);
        _;
    }
    
    modifier beforeEventStart() {
        require(block.timestamp < checkinStart);
        _;
    }
    
    modifier duringEvent() {
        require(block.timestamp >= checkinStart && block.timestamp <= checkinEnd);
        _;
    }
    
    modifier afterDistributionStart() {
        require(block.timestamp > distributionStart);
        _;
    }

    function buyTicket()
        external
        beforeEventStart
        nonReentrant
        payable
    {
        require(msg.value >= getCurrentPrice());
        require(membersBidded[msg.sender] == false);
        require(ticketsAmount > 0);
        
        uint256 bidId = totalSupply();
        membersBids.push(Bid(msg.value, msg.sender));
        super._mint(msg.sender, bidId);
        membersBidded[msg.sender] = true;
        ticketsFunds = ticketsFunds.add(msg.value);
        ticketsAmount = ticketsAmount.sub(1);
        
        if (ticketsAmount == 0) {
            auctionEnd = block.timestamp;
            endPrice = msg.value;
        }
        
        emit TicketBid(bidId, msg.sender, msg.value);
    }
    
    function applyForTalk(
        string _speakerName,
        string _descSpeaker,
        string _deskTalk,
        uint256 _duration
    )
        external
        beforeApplicationStop
        nonReentrant
        payable
    {
        require(_duration >= 900 && _duration <= 3600);
        require(msg.value >= minimalSpeakerDeposit);
        require(speakersTalks.length < 32);
        
        Talk memory t = (Talk(
        {
            speakerName: _speakerName,
            descSpeaker: _descSpeaker,
            deskTalk:    _deskTalk,
            duration:    _duration,
            deposit:     msg.value,
            speakerAddress: msg.sender,
            appliedAt:   block.timestamp,
            checkedIn:   false,
            status:      ApplicationStatus.Applied
        }));
        speakersTalks.push(t);
        
        emit TalkApplication(_speakerName, msg.sender, msg.value);
    }
    
    function acceptTalk(uint256 _talkId)
        external
        onlyOwner
        beforeEventStart
    {
        require(acceptedSpeakersSlots < speakersSlots); 
        acceptedSpeakersSlots = acceptedSpeakersSlots.add(1);
        speakersTalks[_talkId].status = ApplicationStatus.Accepted;
    }
    
    function declineTalk(uint256 _talkId)
        external
        onlyOwner
        beforeEventStart
    {
        speakersTalks[_talkId].status = ApplicationStatus.Declined;
        address(speakersTalks[_talkId].speakerAddress).transfer(speakersTalks[_talkId].deposit);
    }
    
    function checkMissedTalk(uint256 _talkId)
        external
        nonReentrant
    {
        require(block.timestamp > talksApplicationEnd && block.timestamp < checkinStart);
        require(msg.sender == speakersTalks[_talkId].speakerAddress || msg.sender == owner());
        require(speakersTalks[_talkId].status == ApplicationStatus.Applied);
        speakersTalks[_talkId].status = ApplicationStatus.Declined;
        address(speakersTalks[_talkId].speakerAddress).transfer(speakersTalks[_talkId].deposit);
    }
    
    function checkinSpeaker(uint256 _talkId)
        external
        onlyOwner
    {
        require(block.timestamp >= checkinStart && block.timestamp < checkinEnd);
        require(speakersTalks[_talkId].checkedIn == false);
        require(speakersTalks[_talkId].status == ApplicationStatus.Accepted);
        
        uint256 bidId = totalSupply();
        super._mint(msg.sender, bidId);
        speakersTalks[_talkId].checkedIn = true;
    }
    
    function distributeOverbids()
        external
        nonReentrant
        afterDistributionStart
    {   
        uint256 checkedInSpeakers = 0;
        for (uint256 y = 0; y < speakersTalks.length; y++){
            if (speakersTalks[y].checkedIn) checkedInSpeakers++;
        }
        uint256 ticketsForMembersSupply = totalSupply().sub(checkedInSpeakers);
        for (uint256 i = 0; i < ticketsForMembersSupply; i++) {
            address bidderAddress = membersBids[i].bidderAddress;
            uint256 overbid = (membersBids[i].value).sub(endPrice);
            address(bidderAddress).transfer(overbid);
        }
        bidsDistributed = true;
        address(msg.sender).transfer(1000000000000000000);
    }
    
    function distributeRewards()
        external
        nonReentrant
        afterDistributionStart
    {
        require(bidsDistributed == true);
        if (acceptedSpeakersSlots > 0) {
            uint256 checkedInSpeakers = 0;
            for (uint256 i = 0; i < speakersTalks.length; i++){
                if (speakersTalks[i].checkedIn) checkedInSpeakers++;
            }
            uint256 valueForTicketsForReward = endPrice.mul(membersBids.length);
            uint256 valueFromTicketsForSpeakers = 0;
            if (auctionEnd != checkinStart) {
                uint256 mul = auctionEnd.sub(auctionStart).mul(100).div(checkinStart.sub(auctionStart));
                uint256 shares = speakearsStartShares.sub(speakersEndShares).mul(mul).div(100);
                uint256 speakersShares = speakersEndShares.add(shares);
                valueFromTicketsForSpeakers = valueForTicketsForReward.mul(speakersShares).div(100);
            } else {
                valueFromTicketsForSpeakers = valueForTicketsForReward.mul(speakersEndShares).div(100);
            }
            
            uint256 valuePerSpeakerFromTickets = valueFromTicketsForSpeakers.div(checkedInSpeakers);
            for (uint256 y = 0; y < speakersTalks.length; y++) {
                if (speakersTalks[y].checkedIn) {
                    address(speakersTalks[y].speakerAddress).transfer(valuePerSpeakerFromTickets.add(speakersTalks[y].deposit));
                }
            }
        }
        address(msg.sender).transfer(1000000000000000000);
        address(owner()).transfer(address(this).balance);
    }
    
    function setTalksGrid(uint256[] _grid)
        external
        onlyOwner
    {
        talksGrid = _grid;
    }
    
    function setWorkshopsGrid(uint256[] _grid)
        external
        onlyOwner
    {
        workshopsGrid = _grid;
    }
    
    function getTalkById(uint256 _id)
        external
        view
        returns(
            string,
            string,
            string,
            uint256,
            uint256,
            address,
            uint256,
            bool
        )
    {
        require(_id < uint256(speakersTalks.length));
        Talk memory m = speakersTalks[_id];
        return(
            m.speakerName,
            m.descSpeaker,
            m.deskTalk,
            m.duration,
            m.deposit,
            m.speakerAddress,
            m.appliedAt,
            m.checkedIn
        );
    }
    
    function getBidForTicket(uint256 _id)
        external
        view
        returns(uint256, address)
    {
        return(
            membersBids[_id].value,
            membersBids[_id].bidderAddress
        );
    }
    
    function getAuctionStartTime()
        external
        view
        returns(uint256)
    {
        return auctionStart;
    }
    
    function getAuctionEndTime()
        external
        view
        returns(uint256)
    {
        return auctionEnd;
    }
    
    function getEventStartTime()
        external
        view
        returns(uint256)
    {
        return checkinStart;
    }
    
    function getEventEndTime()
        external
        view
        returns(uint256)
    {
        return checkinEnd;
    }
    
    function getDistributionTime()
        external
        view
        returns(uint256)
    {
        return distributionStart;
    }
    
    function getCurrentPrice()
        public
        view
        returns(uint256)
    {
        uint256 secondsPassed = block.timestamp - auctionStart;
        uint256 currentDiscount = (secondsPassed.div(timeframe)).mul(timeframeDowngrade);
        
        if (currentDiscount < (initialPrice - minimalPrice)) {
            return initialPrice.sub(currentDiscount);
        } else { 
            return minimalPrice; 
        }
    }
    
    function getEndPrice()
        external
        view
        returns(uint256)
    {
        return endPrice;
    }
    
    function getMinimalPrice()
        external
        view
        returns(uint256)
    {
        return minimalPrice;
    }
    
    function getMinimalSpeakerDeposit()
        external
        view
        returns(uint256)
    {
        return minimalSpeakerDeposit;
    }
    
    function getTicketsAmount()
        external
        view
        returns(uint256)
    {
        return ticketsAmount;
    }
    
    function getSpeakersSlots()
        external
        view
        returns(uint256)
    {
        return speakersSlots;
    }
    
    function getAvailableSpeaksersSlots()
        external
        view
        returns(uint256)
    { 
        return speakersSlots.sub(acceptedSpeakersSlots); 
    }
    
    function getOrganizersShares()
        external
        view
        returns(uint256)
    {
        return uint256(100).sub(getSpeakersShares());
    }
    
    function getSpeakersShares()
        public
        view
        returns(uint256)
    {
        uint256 time = auctionEnd;
        if ( ticketsAmount > 0 ) time = block.timestamp;
        uint256 mul = time.sub(auctionStart).mul(100).div(checkinStart.sub(auctionStart));
        uint256 shares = speakearsStartShares.sub(speakersEndShares).mul(mul).div(100);
        return speakersEndShares.add(shares);
    }
    
    function getTicketsFunds()
        external
        view
        returns(uint256)
    {
        return ticketsFunds;
    }
    
    function getPlace()
        external
        view
        returns(string)
    { 
        return eventSpace;
    }
    
    function getTalksGrid()
        external
        view
        returns(uint256[])
    {
        return talksGrid;
    }
    
    function getWorkshopsGrid()
        external
        view
        returns(uint256[])
    {
        return workshopsGrid;
    }
}