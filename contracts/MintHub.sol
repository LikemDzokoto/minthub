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


    //assumptive listing price to be changed

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
     mapping(uint256 => Auction) private auctions;


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

    event tokenResale(
      uint256 indexed nftId,
      address indexed buyer,
      uint256 price
    );

    event AuctionCreated(uint256 indexed nftId , address indexed seller , uint256 startingBid , uint256 endTime);
    
    event BidPlaced(uint256 indexed nftId , address indexed bidder , uint256 amount );

    event AuctionExtended(uint256 indexed nftId, uint256 newEndTime);

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

    function getMintHubItem(uint256 nftId) public view returns (mintHubItem memory) {
    return idToMintHubItem[nftId];
  }

    function getAuction(uint256 nftId) public view returns(Auction memory) {
      return auctions[nftId];
    } 

     function _setMintHubItem(uint256 nftId, mintHubItem memory item) internal {
        idToMintHubItem[nftId] = item;
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


    //  idToMintHubItem[nftId] =  mintHubItem({
    //   nftId: nftId,
    //   seller: payable(msg.sender),
    //   owner : payable(address(this)),
    //   price: price,
    //   sold: false
    // });
    
    _setMintHubItem(nftId, mintHubItem({
            nftId: nftId,
            seller: payable(msg.sender),
            owner: payable(address(this)),
            price: price,
            sold: false
        }));

     _transfer(msg.sender, address(this), nftId);
     emit MintHubItemCreated(nftId,  msg.sender,address(this), price, false);

    }



    //allows nft  to resold after initial purchase
    function resellToken(uint256 price , uint256 nftId) public payable {
      // require(idToMintHubItem[nftId].owner == msg.sender, "only nft owner can perform this function");
      require(ownerOf(nftId) == msg.sender, "Only the current owner can resell this token");
      require(msg.value == listingPrice, "Price must be equal to listing price");


      // Check if the item was previously sold
    mintHubItem  memory item = getMintHubItem(nftId);
      if(item.sold){
      _soldItems.decrement(); 
      }

      //update the nft details for resale
      // idToMintHubItem[nftId].sold = false;
      // idToMintHubItem[nftId].price = price;
      // idToMintHubItem[nftId].seller = payable(msg.sender);
      // idToMintHubItem[nftId].owner = payable(address(this));

      _setMintHubItem(nftId, mintHubItem({
            nftId: nftId,
            seller: payable(msg.sender),
            owner: payable(address(this)),
            price: price,
            sold: false
        }));
        



      //transfer the nft back to minthub contract
      _transfer(msg.sender,address(this), nftId);
      
      emit tokenResale(nftId, msg.sender, price);
    }


    function createMintHubItemSale(uint256 nftId) public payable nonReentrant {
      mintHubItem memory item = getMintHubItem(nftId);
      
      require(item.owner == address(this),"nft is not available for sale");

      require(!item.sold,"NFT has already been sold");
      require(msg.value == item.price , "incorrect pricing");

      
      address OriginalSeller = item.seller; 
      uint256 royalty = (item.price * royalties[nftId]) /10_000;

  
    
      // //updated item details
      // item.owner = payable(msg.sender);
      // item.sold = true ;
      // item.seller = payable(address(0)); 

       _setMintHubItem(nftId, mintHubItem({
            nftId: nftId,
            seller: payable(address(0)),
            owner: payable(msg.sender),
            price: item.price,
            sold: true
        }));
        


      _soldItems.increment();

      _transfer(address(this), msg.sender, nftId);

      emit mintHubItemSold(nftId , OriginalSeller, msg.sender, item.price);



    // Pay royalty to the creator
    (bool royaltyPaid, ) = payable(creators[nftId]).call{value: royalty}("");
    require(royaltyPaid, "Royalty payment failed");

    // Pay the remaining amount to the original seller
    (bool sellerPaid, ) = payable(OriginalSeller).call{value: msg.value - royalty}("");
    require(sellerPaid, "Payment to seller failed");
}



    /* =========== AUCTION FUNCTIONS ============ */

    function createAuction(uint256 nftId , uint256 startingBid , uint256 duration) public {
       require(getMintHubItem(nftId).owner == msg.sender, "only  owner  can create an auction");
      require(!auctions[nftId].active, "Already active");

       require(startingBid > 0 && duration > 0, "Invalid parameters");


      // Transfer the NFT from the seller to the marketplace contract
    _transfer(msg.sender, address(this), nftId);


    // Create a new auction

    auctions[nftId] = Auction({

        nftId: nftId,

        seller: payable(msg.sender),

        startingBid: startingBid,

        highestBid: 0,

        highestBidder: payable(address(0)),

        endTime: block.timestamp + duration,

        active: true

    });

    emit AuctionCreated(nftId, msg.sender, startingBid, block.timestamp + duration);

  }



  
    function placeBid(uint256 nftId) public payable nonReentrant{
      Auction storage auction = auctions[nftId];
      require(auction.active && block.timestamp < auction.endTime, "Invalid auction");
      require(msg.value > auction.highestBid && msg.value > 0, "Invalid bid");

      

      // Check if the auction is ending soon and extend the end time if necessary
        if (auction.endTime - block.timestamp < 2 minutes) {
            auction.endTime += 2 minutes;
            emit AuctionExtended(nftId, auction.endTime);
        }

         address payable previousBidder = auction.highestBidder;
         uint256 previousBid = auction.highestBid;


        auction.highestBid = msg.value;
        auction.highestBidder = payable(msg.sender);
        
        if(previousBid > 0){
          (bool refunded, ) = previousBidder.call{value:previousBid}("");
          require(refunded, "Refund to previous Bidder failed");
        }
       

        emit BidPlaced(nftId, msg.sender, msg.value);
    }



    function finalizeAuction(uint256 nftId) public nonReentrant(){
      Auction storage auction = auctions[nftId];
      require(auction.nftId == nftId , "Auction does not exist");
      require(auction.active && block.timestamp >= auction.endTime, "Cannot finalize");

      auction.active = false;

        if (auction.highestBid > 0) {
            uint256 royalty = (auction.highestBid * royalties[nftId]) / 10_000;


            (bool sellerPaid,) = auction.seller.call{value: auction.highestBid - royalty}("");
            require(sellerPaid, "Seller payment failed");


            (bool royaltyPaid, ) = payable(creators[nftId]).call{value:royalty}("");
            require(royaltyPaid, "Royalty payment failed"); 
            

            _transfer(address(this), auction.highestBidder, nftId);
        } else {
            _transfer(address(this), auction.seller, nftId);
        }

        emit AuctionFinalized(nftId, auction.highestBidder, auction.highestBid);
    }
    


    function cancelAuction(uint256 nftId) public {
      Auction storage auction = auctions[nftId];
      require(auction.active && auction.seller == msg.sender, "Cannot cancel");
      require(auction.highestBid == 0 && block.timestamp < auction.endTime, "Invalid state");



      auction.active = false;
      _transfer(address(this), auction.seller, nftId);
      emit AuctionCancelled(nftId, auction.seller);
    }  



    /* =========== FETCH  FUNCTIONS ============ */

    function fetchMintHubItems() public view returns(mintHubItem[] memory){
       uint256 nftCount = _nftIds.current();
        uint256 unsoldnftCount = _nftIds.current() - _soldItems.current();
        uint256 currentIndex = 0;

        mintHubItem[] memory nftItems = new  mintHubItem[](unsoldnftCount);
        for (uint256 i = 0; i <nftCount; i++) {
            if ( idToMintHubItem[i + 1].owner == address(this)) {
                uint256 currentId = i + 1;
               mintHubItem memory currentItem = idToMintHubItem[currentId];
                nftItems[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
             return nftItems;
    }

    



    function fetchMyNfts() public view  returns(mintHubItem[] memory){
       uint256 totalnftCount = _nftIds.current();
        uint256 nftCount = 0;
        uint256 currentIndex = 0;

        for (uint256 i = 0; i < totalnftCount; i++) {
            if (idToMintHubItem[i + 1].owner == msg.sender) {
                nftCount += 1;
            }
        }

        mintHubItem[] memory nftItems = new mintHubItem[](nftCount);
        for (uint256 i = 0; i < totalnftCount; i++) {
            if (idToMintHubItem[i + 1].owner == msg.sender) {
                uint256 currentId = i + 1;
               mintHubItem memory currentItem = idToMintHubItem[currentId];
                nftItems[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return nftItems;
    }



    function fetchListedItems() public view returns (mintHubItem[] memory){
      uint256 totalnftCount = _nftIds.current();
        uint256 nftCount = 0;
        uint256 currentIndex = 0;

        for (uint256 i = 0; i < totalnftCount; i++) {
            if (idToMintHubItem[i + 1].seller == msg.sender) {
                nftCount += 1;
            }
        }

        mintHubItem[] memory nftItems = new mintHubItem[](nftCount);


        for (uint256 i = 0; i < totalnftCount; i++) {
            if (idToMintHubItem[i + 1].seller == msg.sender) {
                uint256 currentId = i + 1;
               mintHubItem memory currentItem = idToMintHubItem[currentId];
                nftItems[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return nftItems;

    }
}

