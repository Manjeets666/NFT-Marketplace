pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

contract nftSale{
    address public creator;
    address public buyer;
    uint sellingPrice;

    //Functions
    fixSale() public {}
    buyNow() public {
        require(msg.value >= sellingPrice);
        safeTransfer(msg.sender,creator,sellingPrice);
        nftTransfer();
        //refund amount if buyer gives extra price 
        if (msg.value > sellingPrice){
            safeTransfer(msg.sender, msg.value - sellingPrice);
        }
    }
}

contract nftAuction{
    //parametrs
    address public seller;
    address public investor;
    uint basePrice;
    uint public endTime;

    uint public highestBid;
    address public highestBidder;
    //we need mapping to store the bidAmount of every Bidder
    mapping(address => uint) public returnableAmounts;
    //to see if auction is ended or not
    modifier isEnded(){
        bool ended= false;
    }
    //events
    event auctionEnded(address highestBidder, uint highestBid);

    constructor(uint basePrice)
}


