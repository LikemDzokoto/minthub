// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.28;


import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";



contract MintHub is ERC721URIStorage , ReentrancyGuard{
     using Counters for Counters.Counter;
     Counters.Counter private _nftId;
     Counters.Counter private _soldItems;



    address payable private owner;


    //assumptive listing price to be 

    uint256 listingPrice = 0.001 ether;




   /* =========== STRUCTS ============ */



    struct mintHubItem{
        uint256 nftId;
        uint256 tokenId;
        address payable creator;
        address payable seller;
        address payable owner;
        uint256 price;
        bool sold;

        }


    struct Auction{
      uint256 nftId;
      address payable seller;
      uint256 startingBid;
      uint256 highestBid;
      address payable highestBidder;
      uint256 endTime;
      bool active;
    }



    
     /* =========== MAPPINGS ============ */

     mapping(uint256 => mintHubItem) private idToMintHubItem ;
     mapping(uint256 => Auction) private auction;


     //Royalties 
     mapping(uint256 => address) public creators;
     mapping(uint256 => uint256) public royalties;


      /* =========== EVENTS ============ */
      event MintHubItemCreated(
        uint256 indexed nftId,
        address indexed nftContract,
        address creator,
        address seller,
        address owner,
        uint256 price,
        bool sold
    );


    event AuctionCreated(uint256 indexed nftId , address indexed seller , uint256 startingBid , uint256 endTime);
    
    event BidPlaced(uint256 indexed nftId , address indexed bidder , uint256 amount );

    event AuctionFinalized(uint256 indexed nftId , address indexed winner , uint256 amount);

    event AuctionCancelled(uint256 indexed nftId , address indexed seller);



    constructor() ERC721("MintHub Token", "MHT") {
      owner = payable(msg.sender);
    }

    modifier onlyOwner(){
      require(msg.sender == owner , "Only mintHub owner can perform this action");
      _;
    }


    /* =========== HELPER FUNCTIONS ============ */


    function getListingPrice() public view returns (uint256){
      return listingPrice;
    }

    function updateListingPricing(uint256 _listingPrice) public onlyOwner{
      listingPrice = _listingPrice;
    } 


    /* =========== MAIN  FUNCTIONS ============ */

    function createToken() public payable returns(uint256){}



    function createMintHubItem() private {}


    function resellToken() public payable {}


    function createMintHubItemSale() public payable nonReentrant {}



    /* =========== AUCTION FUNCTIONS ============ */

    function createAuction() public {

    }

    function placeBid() public payable nonReentrant{}


    function finalizeAuction() public nonReentrant(){}


    function cancelAuction() public {}  



    /* =========== FETCH  FUNCTIONS ============ */

    function fetchMintHubItem() public view returns(mintHubItem[] memory){}


    
}
