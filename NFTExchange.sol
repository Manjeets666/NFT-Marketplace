//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
contract PriceConsumerV3 {
    AggregatorV3Interface internal priceFeed;

    /**
     * Network: Rinkeby
     * Aggregator: ETH/USD
     * Address: 0x8A753747A1Fa494EC906cE90E9f37563A8AF630e
     */
    constructor()  {
        priceFeed = AggregatorV3Interface(0x8A753747A1Fa494EC906cE90E9f37563A8AF630e);
    }
    
    //convert amount and denominator to wei values with multipliers
    //multipliers are needed for accurate division
    function ethUSD(uint256 _amount) public view returns (uint256) {
         uint256 denominator = uint256(getLatestPrice()); 
        uint256 ethInUsdAmount = _amount * 1000000000000000000000/denominator * 100000; 
        return ethInUsdAmount;
    }
    
    /**
     * Returns the latest price of ETH/USD from Chain.link
     */
    function getLatestPrice() public view returns (int) {
        (,int price,,,) = priceFeed.latestRoundData();
        return price;
    }
}

contract nftExchange is ERC721, PriceConsumerV3 {
    event NftBought(address _seller, address _buyer, uint256 _sellingPrice);
    event AuctionEnded(address winner, uint256 amount);
    event BidSuccess(address bidder, uint256 amount, uint256 _id);
    event AuctionCreated(address creator, uint256 _id, uint256 _basePrice);

    mapping (uint256 => address payable) public seller;
    mapping (uint256 => uint256) public idToPrice;
    mapping (uint256 => uint256) public endTime;
    mapping (uint256 => address) public highestBidder;
    mapping (uint256 => uint256) public highestBid;
    mapping (uint256 => uint256) public idToBasePrice;
    // Mapping from id to mapping from bidCount to user bid data
    mapping(uint256 => mapping (uint256 => Bid)) public bids;
    //to store no. of bids for each id
    mapping (uint256 => uint256) public bidCount;
    // Bid struct to hold bidder and amount
    struct Bid {
        address payable bidder;
        uint256 amount;
}

    constructor() ERC721('', '') {}

    modifier onlySeller(uint256 _id) {
        require(seller[_id] == msg.sender, "caller is not the seller");
        _;
    }
    modifier notNftSeller(uint256 _id) {
        require(msg.sender != seller[_id], "Owner cannot buy/bid own NFT");
        _;
    }
    //to see if auction is ended or not
    modifier auctionOngoing(uint256 _id) {
        require(isAuctionOngoing(_id),"This auction has ended");
        _;
    }

    function allowForSale(uint256 _id, uint256 _sellingPrice) external {
        require(msg.sender == ownerOf(_id), "Not owner of this NFT");
        require(_sellingPrice > 0, "Price zero");
        idToPrice[_id] = _sellingPrice;
        transferNftToContract(_id);
        seller[_id]= payable(msg.sender);
    }

    function cancelNftSale(uint256 _id) external onlySeller(_id){
        uint256 price = idToPrice[_id];
        require(price > 0, "This NFT is not for sale");
        _transfer(address(this),seller[_id], _id);
        require(ownerOf(_id) != address(this),"NFT transfer failed");
        resetSale(_id);
    }

    function transferNftToContract(uint256 _id) internal {
        _transfer(ownerOf(_id), address(this), _id);
        require(ownerOf(_id) == address(this),"NFT transfer failed");
    }

    function resetSale(uint256 _id) internal {
        idToPrice[_id] = 0;
        seller[_id] = payable(address(0));
    }
    
    function buyNFT(uint256 _id) external payable notNftSeller(_id){
        uint256 price = idToPrice[_id];
        require(price > 0, "This NFT is not for sale");
        require(msg.value == price, "Incorrect value");
        _transfer(address(this), msg.sender, _id);
        seller[_id].transfer(msg.value - (msg.value * 25/1000)); // send the ETH to the seller with 2.5% fee
        resetSale(_id);

        emit NftBought(seller[_id], msg.sender, msg.value);
    }
    
    function changeSellPrice(uint256 _id, uint256 _newPrice) external onlySeller(_id){
        uint256 price = idToPrice[_id];
        require(price > 0, "This NFT is not for sale");
        idToPrice[_id] = _newPrice;
    }

    function sellAsAuction(uint256 _id, uint256 _basePrice, uint256 _endTime) external payable{
        require(msg.sender == ownerOf(_id), "Not owner of this NFT");
        require(_basePrice > 0, "Price zero");
        seller[_id]= payable(msg.sender);
        endTime[_id]= block.timestamp + _endTime;
        uint256 ethPrice = ethUSD(_basePrice);
        idToBasePrice[_id] = ethPrice;
        transferNftToContract(_id);

        emit AuctionCreated(msg.sender, _id, _basePrice);   
    }
    
    function makeBid(uint256 _id) external payable notNftSeller(_id) auctionOngoing(_id) {
        require(idToBasePrice[_id] > 0, "This NFT is not in auction");
        require(msg.value >= idToBasePrice[_id] && msg.value > highestBid[_id],"There is already a higher or equal bid");
        bids[_id][bidCount[_id]].bidder = payable(msg.sender);
        bids[_id][bidCount[_id]].amount += msg.value;
        highestBidder[_id]= bids[_id][bidCount[_id]].bidder;
        highestBid[_id]= bids[_id][bidCount[_id]].amount;
        bidCount[_id]++;

        emit BidSuccess(msg.sender, msg.value, _id);
    }

    function isAuctionOngoing(uint256 _id) internal view returns (bool){
        return(block.timestamp <= endTime[_id] );
    }

    function refundBidders(uint256 _id) internal {
        for(uint8 i = 0; i < bidCount[_id]-1; i++){
            address payable addr = bids[_id][i].bidder;
            uint256 amt = bids[_id][i].amount;
            addr.transfer(amt);
        }
    }

    function resetAuction(uint256 _id) internal{
        idToBasePrice[_id] = 0; // not for auction anymore       
        seller[_id] = payable(address(0));
        endTime[_id] = 0;
        highestBidder[_id] = payable(address(0));
        highestBid[_id] = 0;
        for(uint8 i = 0; i < bidCount[_id]; i++){
            bids[_id][i].bidder = payable(address(0));
            bids[_id][i].amount = 0;
        }
        bidCount[_id] = 0;
    }

    function endAuction(uint256 _id) external payable onlySeller(_id) auctionOngoing(_id){
        if(bidCount[_id] > 0){ //to check if there are bidders or not
            _transfer(address(this), highestBidder[_id], _id);
            seller[_id].transfer(highestBid[_id]-(highestBid[_id] * 25/1000)); // send the ETH to the seller with 2.5% fee
            refundBidders(_id);
        }
        resetAuction(_id);

        emit AuctionEnded(highestBidder[_id],highestBid[_id]);
    }
}
