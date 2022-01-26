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
    constructor() public {
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

contract nftSale is ERC721 {
    event NftBought(address _seller, address _buyer, uint256 _sellingPrice);

    mapping (uint256 => uint256) public idToPrice;

    constructor() ERC721('MyNFT', 'MY') {
        _mint(msg.sender, 1);
    }

    function allowForSale(uint256 _id, uint256 _sellingPrice) external {
        require(msg.sender == ownerOf(_id), "Not owner of this NFT");
        require(_sellingPrice > 0, "Price zero");
        idToPrice[_id] = _sellingPrice;
        transferNftToContract(_id);
    }

    function transferNftToContract(uint256 _id) internal {
        _transfer(ownerOf(_id), address(this), _id);
        require(ownerOf(_id) == address(this),"NFT transfer failed");
    }
    
    function buyNFT(uint256 _id) external payable {
        uint256 price = idToPrice[_id];
        require(price > 0, "This NFT is not for sale");
        require(msg.value == price, "Incorrect value");
        
        address seller = ownerOf(_id);
        _transfer(seller, msg.sender, _id);
        idToPrice[_id] = 0; // not for sale anymore
        payable(seller).transfer(msg.value - (msg.value * 25/1000)); // send the ETH to the seller with 2.5% fee

        emit NftBought(seller, msg.sender, msg.value);
    }
}

contract nftAuction is ERC721, PriceConsumerV3  {
    //parametrs
    uint256 public endTime;
    uint256 public highestBid;
    uint256 public bidderCount;
    address payable public seller;
    address payable public highestBidder;
//     struct Bidder {
//         address payable addr;
//         uint256 amount;
// }
    mapping (uint256 => uint256) public idToBasePrice;
    //we need mapping to store the bidAmount of every Bidder
    mapping(address => uint256) public bidders;
    //to see if auction is ended or not
    modifier isEnded(){
        require(block.timestamp > endTime, "The auction has been ended"); 
        _;
    }
    modifier onlySeller() {
        require(seller == msg.sender, "caller is not the seller");
        _;
    }
    modifier notNftSeller(uint256 _id) {
        require(msg.sender != seller, "Owner cannot bid on own NFT");
        _;
    }
    modifier auctionOngoing(uint256 _id) {
        require(isAuctionOngoing(_id),"Auction has ended");
        _;
    }
    // modifier isAuctionOver(uint256 _id) {
    //     require(!isAuctionOngoing(_id),"Auction is not yet over");
    //     _;
    // }

    //events
    event AuctionEnded(address winner, uint256 amount);

    constructor() ERC721('MyNFT', 'MY') {
        _mint(msg.sender, 1);
    }

    function sellAsAuction(uint256 _id, uint256 _basePrice, uint256 _endTime) external {
        require(msg.sender == ownerOf(_id), "Not owner of this NFT");
        require(_basePrice > 0, "Price zero");
        seller= payable(msg.sender);
        endTime= block.timestamp + _endTime;
        uint256 ethPrice = ethUSD(_basePrice);
        idToBasePrice[_id] = ethPrice;
        transferNftToContract(_id);
        
    }
    
    function makeBid(uint256 _id) external payable isEnded notNftSeller(_id) auctionOngoing(_id) {
        require(idToBasePrice[_id] > 0, "This NFT is not auction");
        require(msg.value >= idToBasePrice[_id] && msg.value > highestBid,"There is already a higher or equal bid");
        if(highestBid != 0){
            bidders[highestBidder] += highestBid;
        }
        highestBidder= payable(msg.sender);
        highestBid= msg.value;
        // bidderCount++;
        // bidders[bidderCount]= Bidder(highestBidder,highestBid);
    }

    function isAuctionOngoing(uint256 _id) internal view returns (bool){
        return(endTime == 0 || block.timestamp <= endTime );
    }

    function transferNftToContract(uint256 _id) internal {
        _transfer(ownerOf(_id), address(this), _id);
        require(ownerOf(_id) == address(this),"NFT transfer failed");
    }

    // function refundBidders() internal {
    //     for(uint8 i=0; i < bidderCount-1; i++){

    //     }
    // }

    function endAuction(uint256 _id) external payable onlySeller auctionOngoing(_id){
        _transfer(address(this), highestBidder, _id);
        idToBasePrice[_id] = 0; // not for auction anymore
        payable(seller).transfer(highestBid-(highestBid * 25/1000)); ///// send the ETH to the seller with 2.5% fee
        emit AuctionEnded(highestBidder,highestBid);

    }
}
