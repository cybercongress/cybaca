pragma solidity 0.4.25;

import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "openzeppelin-solidity/contracts/token/ERC721/ERC721Full.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/utils/ReentrancyGuard.sol";
import "openzeppelin-solidity/contracts/utils/Address.sol";


contract Cybercon is Ownable, ReentrancyGuard, ERC721Full {
    
    using SafeMath for uint256;
    using Address for address;
    
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
    uint256 constant private TALKS_APPLICATION_END = 1543339800;
    uint256 private auctionEnd = 1543345200;
    uint256 constant private CHECKIN_START = 1543345200;
    uint256 constant private CHECKIN_END = 1543347000;
    uint256 constant private DISTRIBUTION_START = 1543348800;
    // ------------
    uint256 constant private INITIAL_PRICE = 1000 finney;
    uint256 constant private MINIMAL_PRICE = 40 finney;
    uint256 private endPrice = 40 finney;
    uint256 constant private TIMEFRAME = 50;
    uint256 constant private BID_TIMEFRAME_DECREASE = 2 finney;
    // ------------
    uint256 private ticketsAmount = 100;
    uint256 constant private SPEAKERS_SLOTS = 10;
    uint256 private acceptedSpeakersSlots = 0;
    uint256 constant private SPEAKERS_START_SHARES = 80;
    uint256 constant private SPEAKERS_END_SHARES = 20;
    // ------------
    uint256 private ticketsFunds = 0;
    uint256 constant private MINIMAL_SPEAKER_DEPOSIT = 1000 finney;
    // ------------
    string constant private CYBERCON_PLACE = "Korpus 8";
    
    mapping(address => bool) private membersBidded;
    bool private overbidsDistributed = false;
    
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
    
    modifier onlyIfAddress(address _caller) {
        require(_caller.isContract() == false);
        _;
    }
    
    modifier beforeApplicationStop() {
        require(block.timestamp < TALKS_APPLICATION_END);
        _;
    }
    
    modifier beforeEventStart() {
        require(block.timestamp < CHECKIN_START);
        _;
    }
    
    modifier duringEvent() {
        require(block.timestamp >= CHECKIN_START && block.timestamp <= CHECKIN_END);
        _;
    }
    
    modifier afterDistributionStart() {
        require(block.timestamp > DISTRIBUTION_START);
        _;
    }

    function buyTicket()
        external
        beforeEventStart
        onlyIfAddress(msg.sender)
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
        onlyIfAddress(msg.sender)
        nonReentrant
        payable
    {
        require(_duration >= 900 && _duration <= 3600);
        require(msg.value >= MINIMAL_SPEAKER_DEPOSIT);
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
    
    function updateTalkDescription(
        uint256 _talkId,
        string _descSpeaker,
        string _deskTalk
    )
        external
        beforeApplicationStop
        onlyIfAddress(msg.sender)
        nonReentrant
    {
        require(msg.sender == speakersTalks[_talkId].speakerAddress);
        speakersTalks[_talkId].descSpeaker = _descSpeaker;
        speakersTalks[_talkId].deskTalk = _deskTalk;
    }
    
    function acceptTalk(uint256 _talkId)
        external
        onlyOwner
        beforeEventStart
    {
        require(acceptedSpeakersSlots < SPEAKERS_SLOTS); 
        require(speakersTalks[_talkId].status == ApplicationStatus.Applied);
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
    
    function selfDeclineTalk(uint256 _talkId)
        external
        onlyIfAddress(msg.sender)
        nonReentrant
    {
        require(block.timestamp >= TALKS_APPLICATION_END && block.timestamp < CHECKIN_START);
        require(msg.sender == speakersTalks[_talkId].speakerAddress);
        require(speakersTalks[_talkId].status == ApplicationStatus.Applied);
        speakersTalks[_talkId].status = ApplicationStatus.Declined;
        address(speakersTalks[_talkId].speakerAddress).transfer(speakersTalks[_talkId].deposit);
    }
    
    function checkinSpeaker(uint256 _talkId)
        external
        onlyOwner
    {
        require(block.timestamp >= CHECKIN_START && block.timestamp < CHECKIN_END);
        require(speakersTalks[_talkId].checkedIn == false);
        require(speakersTalks[_talkId].status == ApplicationStatus.Accepted);
        
        uint256 bidId = totalSupply();
        super._mint(msg.sender, bidId);
        speakersTalks[_talkId].checkedIn = true;
    }
    
    function distributeOverbids()
        external
        nonReentrant
        onlyIfAddress(msg.sender)
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
        overbidsDistributed = true;
        address(msg.sender).transfer(1000000000000000000);
    }
    
    function distributeRewards()
        external
        nonReentrant
        onlyIfAddress(msg.sender)
        afterDistributionStart
    {
        require(overbidsDistributed == true);
        if (acceptedSpeakersSlots > 0) {
            uint256 checkedInSpeakers = 0;
            for (uint256 i = 0; i < speakersTalks.length; i++){
                if (speakersTalks[i].checkedIn) checkedInSpeakers++;
            }
            uint256 valueForTicketsForReward = endPrice.mul(membersBids.length);
            uint256 valueFromTicketsForSpeakers = 0;
            if (auctionEnd != CHECKIN_START) {
                uint256 mul = auctionEnd.sub(auctionStart).mul(100).div(CHECKIN_START.sub(auctionStart));
                uint256 shares = SPEAKERS_START_SHARES.sub(SPEAKERS_END_SHARES).mul(mul).div(100);
                uint256 speakersShares = SPEAKERS_END_SHARES.add(shares);
                valueFromTicketsForSpeakers = valueForTicketsForReward.mul(speakersShares).div(100);
            } else {
                valueFromTicketsForSpeakers = valueForTicketsForReward.mul(SPEAKERS_END_SHARES).div(100);
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
            bool,
            ApplicationStatus
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
            m.checkedIn,
            m.status
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
        pure
        returns(uint256)
    {
        return CHECKIN_START;
    }
    
    function getEventEndTime()
        external
        pure
        returns(uint256)
    {
        return CHECKIN_END;
    }
    
    function getDistributionTime()
        external
        pure
        returns(uint256)
    {
        return DISTRIBUTION_START;
    }
    
    function getCurrentPrice()
        public
        view
        returns(uint256)
    {
        uint256 secondsPassed = block.timestamp - auctionStart;
        uint256 currentDiscount = (secondsPassed.div(TIMEFRAME)).mul(BID_TIMEFRAME_DECREASE);
        
        if (currentDiscount < (INITIAL_PRICE - MINIMAL_PRICE)) {
            return INITIAL_PRICE.sub(currentDiscount);
        } else { 
            return MINIMAL_PRICE; 
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
        pure
        returns(uint256)
    {
        return MINIMAL_PRICE;
    }
    
    function getMinimalSpeakerDeposit()
        external
        pure
        returns(uint256)
    {
        return MINIMAL_SPEAKER_DEPOSIT;
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
        pure
        returns(uint256)
    {
        return SPEAKERS_SLOTS;
    }
    
    function getAvailableSpeaksersSlots()
        external
        view
        returns(uint256)
    { 
        return SPEAKERS_SLOTS.sub(acceptedSpeakersSlots); 
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
        uint256 mul = time.sub(auctionStart).mul(100).div(CHECKIN_START.sub(auctionStart));
        uint256 shares = SPEAKERS_START_SHARES.sub(SPEAKERS_END_SHARES).mul(mul).div(100);
        return SPEAKERS_END_SHARES.add(shares);
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
        pure
        returns(string)
    { 
        return CYBERCON_PLACE;
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