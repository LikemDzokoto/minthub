// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.28;


import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";



contract MintHub is ERC721URIStorage , ReentrancyGuard{
     using Counters for Counters.Counter;
     Counters.Counter private _nftIds;
     Counters.Counter private _soldItems;



    address payable private owner;


    //assumptive listing price to be 

    uint256 listingPrice = 0.001 ether;




   /* =========== STRUCTS ============ */



    struct mintHubItem{
        uint256 nftId;
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
        address seller,
        address owner,
        uint256 price,
        bool sold
    );


    event mintHubItemSold(
      uint256  indexed nftId,
      address indexed seller,
      address indexed buyer,
      uint256 price 
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


    //create a new NFT and list it on MintHub
    function createToken(string memory tokenURI , uint256 price , uint256 royalty) public payable returns(uint256){
      //validation to make sure royalty point does not exceed 100% , expressed in basis points
      require(royalty <= 10000 , "Royalty must be 100% or less " );

      _nftIds.increment();

      uint256 newNftId = _nftIds.current();
      _safeMint(msg.sender , newNftId);
      _setTokenURI(newNftId , tokenURI);

      creators[newNftId] = msg.sender;
      royalties[newNftId]  = royalty;

      createMintHubItem(newNftId , price );
      return newNftId;

    }



    function createMintHubItem(uint256 nftId, uint256 price) private {
      require(price > 0 , "nft price must be at least one wei or more");
      require(msg.value == listingPrice , "nft price must be equal to listing Price");


     idToMintHubItem[nftId] =  mintHubItem(
      nftId,
      payable(msg.sender),
      payable(address(this)),
      price,
      false
     );

     _transfer(msg.sender, address(this), nftId);
     emit MintHubItemCreated(nftId,  msg.sender,address(this), price, false);

    }



    //allows nft  to resold after initial purchase
    function resellToken(uint256 price , uint256 nftId) public payable {
      require(idToMintHubItem[nftId].owner == msg.sender, "only nft owner can perform this function");
      require(msg.value == listingPrice, "Price must be equal to listing price");

      idToMintHubItem[nftId].sold = false;
      idToMintHubItem[nftId].price = price;
      idToMintHubItem[nftId].seller = payable(msg.sender);
      idToMintHubItem[nftId].owner = payable(address(this));

      _soldItems.decrement();
      _transfer(msg.sender,address(this), nftId);
    }


    function createMintHubItemSale(uint256 nftId) public payable nonReentrant {
      mintHubItem storage item = idToMintHubItem[nftId];

      uint256 price = item.price;
      address OriginalSeller = item.seller;
      uint256 royalty = (price * royalties[nftId]) / 1000;

      require(msg.value == price , "kindly submit the asking price to sucessfully complete  the purchase");


      //updated item details
      item.owner = payable(msg.sender);
      item.sold = true ;
      item.seller = payable(address(0));  // Reset seller to zero address

      _soldItems.increment();

      _transfer(address(this), msg.sender, nftId);

      emit mintHubItemSold(nftId , OriginalSeller, msg.sender, price);



    // Pay royalty to the creator
    (bool royaltyPaid, ) = payable(creators[nftId]).call{value: royalty}("");
    require(royaltyPaid, "Royalty payment failed");

    // Pay the remaining amount to the original seller
    (bool sellerPaid, ) = payable(OriginalSeller).call{value: msg.value - royalty}("");
    require(sellerPaid, "Payment to seller failed");
}






    /* =========== AUCTION FUNCTIONS ============ */

    function createAuction() public {

    }

    function placeBid() public payable nonReentrant{}


    function finalizeAuction() public nonReentrant(){}


    function cancelAuction() public {}  



    /* =========== FETCH  FUNCTIONS ============ */

    function fetchMintHubItem() public view returns(mintHubItem[] memory){}

    function fetchMyNfts() public view  returns(mintHubItem[] memory){}



    function fetchListedItems() public view returns (mintHubItem[] memory){}


    
}

