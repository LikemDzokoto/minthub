// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract Tokenated is  ERC721URIStorage , ReentrancyGuard, AccessControl, Pausable{
    using Counters for Counters.Counter;
    
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant MODERATOR_ROLE = keccak256("MODERATOR_ROLE");
    uint256 public constant MIN_BID_INCREMENT = 0.01 ether;
    uint256 public constant MAX_AUCTION_DURATION = 7 days;
    uint256 public constant MIN_AUCTION_DURATION = 1 hours;

    Counters.Counter private _nftIds;
    Counters.Counter private _soldItems;
    
    uint256 private listingPrice = 0.001 ether;
    uint256 private platformFee = 250; 
    
    struct NFTItem {
        uint256 nftId;
        address payable creator;
        address payable seller;
        address payable owner;
        uint256 price;
        uint256 royalty;
        bool sold;
        bool isAuction;
        bool isListed;
    }
    
    struct Auction {
        uint256 nftId;
        address payable seller;
        uint256 startingBid;
        uint256 highestBid;
        address payable highestBidder;
        uint256 endTime;
        bool active;
        uint256 minBidIncrement;
    }
    
    mapping(uint256 => NFTItem) private _nfts;
    mapping(uint256 => Auction) private _auctions;
    mapping(address => uint256) private _escrowBalances;
    mapping(address => bool) private _blackListedUsers;
    
    
    event NFTListed(uint256 indexed nftId, address seller, uint256 price);
    event NFTSold(uint256 indexed nftId, address seller, address buyer, uint256 price);
    event AuctionCreated(uint256 indexed nftId, address seller, uint256 startingBid, uint256 endTime);
    event BidPlaced(uint256 indexed nftId, address bidder, uint256 amount);
    event AuctionEnded(uint256 indexed nftId, address winner, uint256 amount);
    event RoyaltyPaid(uint256 indexed nftId, address creator, uint256 amount);
    event FeeUpdated(string feeType, uint256 newAmount);
    event FundsWithdrawn(address indexed recipient, uint256 amount);
    event Blacklisted(address indexed user);
    event UnBlacklisted(address indexed user);
    event PriceUpdated(uint256 indexed nftId, uint256 newPrice);
    event ListingCancelled(uint256 indexed nftId, address indexed seller);


    modifier validNFT(uint256 nftId) {
    require(_nfts[nftId].nftId == nftId, "NFT does not exist");
    _;
    }

    modifier onlyNFTOwner(uint256 nftId) {
        require(_nfts[nftId].owner == msg.sender || _nfts[nftId].seller == msg.sender, "Not NFT owner");
        _;
    }
    

    

    
    constructor() ERC721("Tokenated", "TKH") {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(ADMIN_ROLE, msg.sender);
    }
    
   
    
    function addAdmin(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(ADMIN_ROLE, account);
    }
    
    function addModerator(address account) external onlyRole(ADMIN_ROLE) {
        grantRole(MODERATOR_ROLE, account);
    }

    function blackList(address  account) external onlyRole(ADMIN_ROLE){
         _blackListedUsers[account] = true;
        emit Blacklisted( account);
    }
    function unBlackList(address  account) external onlyRole(ADMIN_ROLE){
        _blackListedUsers[account] = false;
        emit UnBlacklisted( account);
    }
    
    function setListingPrice(uint256 newPrice) external onlyRole(ADMIN_ROLE) {
        listingPrice = newPrice;
        emit FeeUpdated("listing", newPrice);
    }
    
    function setPlatformFee(uint256 newFee) external onlyRole(ADMIN_ROLE) {
        require(newFee <= 1000, "Fee cannot exceed 10%");
        platformFee = newFee;
        emit FeeUpdated("platform", newFee);
    }
    
    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }
    
    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }
    
    function withdrawFees() external onlyRole(ADMIN_ROLE) {
        uint256 balance = address(this).balance;
        require(balance > 0, "No fees to withdraw");
        (bool success, ) = payable(msg.sender).call{value: balance}("");
        require(success, "Transfer failed");
        emit FundsWithdrawn(msg.sender, balance);
    }
    
   
    function mintNFT(string memory tokenURI, uint256 price, uint256 royalty) 
        external 
        payable 
        whenNotPaused 
        returns (uint256) 
    {   
        require(!_blackListedUsers[msg.sender],"address is blacklisted");
        require(msg.value == listingPrice, "Incorrect listing fee");
        require(royalty <= 1000, "Royalty cannot exceed 10%");
        require(bytes(tokenURI).length > 0, "Empty URI");
        require(price > 0, "Price must be greater than 0");
        
        
        _nftIds.increment();
        uint256 newNftId = _nftIds.current();
        
        _safeMint(msg.sender, newNftId);
        _setTokenURI(newNftId, tokenURI);

        _transfer(msg.sender, address(this), newNftId);

      

        _nfts[newNftId] = NFTItem({
            nftId: newNftId,
            creator: payable(msg.sender),
            seller: payable(msg.sender),
            owner: payable(address(this)),
            price: price,
            royalty: royalty,
            sold: false,
            isAuction: false,
            isListed: true
        });
        
        
        
        emit NFTListed(newNftId, msg.sender, price);
        
        return newNftId;
    }
    
    function buyNFT(uint256 nftId) 
        external 
        payable 
        nonReentrant 
        whenNotPaused 
        validNFT(nftId)
    {
        NFTItem storage nft = _nfts[nftId];
        
        require(!_blackListedUsers[msg.sender],"address is blacklisted");
        require(!nft.sold && !nft.isAuction && !nft.isListed, "NFT not available");
        require(msg.value == nft.price, "Incorrect price");

        uint256 royaltyAmount = (msg.value * nft.royalty) / 10000;
        uint256 platformAmount = (msg.value * platformFee) / 10000;
        uint256 sellerAmount = msg.value - royaltyAmount - platformAmount;
        
        _escrowBalances[nft.creator] += royaltyAmount;
        _escrowBalances[nft.seller] += sellerAmount;
        
        nft.sold = true;
        nft.isListed = false;
        nft.owner = payable(msg.sender);
        
        _transfer(address(this), msg.sender, nftId);
        emit NFTSold(nftId, nft.seller, msg.sender, msg.value);
        emit RoyaltyPaid(nftId, nft.creator, royaltyAmount);
    }
    
    function createAuction(uint256 nftId, uint256 startingBid, uint256 duration, uint256 minBidIncrement)
        external
        whenNotPaused
        validNFT(nftId)
    {
        require(!_blackListedUsers[msg.sender],"address is blacklisted");
 
        require(ownerOf(nftId) == address(this), "Contract does not hold the NFT");
        require(_nfts[nftId].seller == msg.sender, "Only the seller can create an auction");
        require(!_nfts[nftId].sold, "NFT already sold");

        require(duration >= MIN_AUCTION_DURATION && duration <= MAX_AUCTION_DURATION, "Invalid duration");
        require(startingBid > 0, "Invalid starting bid");
        require(minBidIncrement >= MIN_BID_INCREMENT, "Bid increment too low");
        
        _auctions[nftId] = Auction({
            nftId: nftId,
            seller: payable(msg.sender),
            startingBid: startingBid,
            highestBid: 0,
            highestBidder: payable(address(0)),
            endTime: block.timestamp + duration,
            active: true,
            minBidIncrement: minBidIncrement
        });
        
        _nfts[nftId].isAuction = true;
        _nfts[nftId].isListed = false;
        
        
        emit AuctionCreated(nftId, msg.sender, startingBid, block.timestamp + duration);
    }
    
    function placeBid(uint256 nftId)
        external
        payable
        nonReentrant
        whenNotPaused
        validNFT(nftId)
    {
        Auction storage auction = _auctions[nftId];
        require(!_blackListedUsers[msg.sender],"address is blacklisted");
        require(auction.active && block.timestamp < auction.endTime, "Auction ended/invalid");
        require(msg.value > auction.highestBid && msg.value >= auction.startingBid, "Bid too low");
        require(msg.sender != auction.seller, "Seller cannot bid");
        

        if (auction.highestBid == 0) {
            require(msg.value >= auction.startingBid, "Bid below starting price");
        } else {
            require(msg.value >= auction.highestBid + auction.minBidIncrement, "Bid too low");
        }

        if(auction.highestBidder != address(0)) {
            _escrowBalances[auction.highestBidder] += auction.highestBid;
        }
        
        auction.highestBid = msg.value;
        auction.highestBidder = payable(msg.sender);
        
        emit BidPlaced(nftId, msg.sender, msg.value);
    }
    
    function finalizeAuction(uint256 nftId)
        external
        nonReentrant
        whenNotPaused
        validNFT(nftId)
    {
        Auction storage auction = _auctions[nftId];
        require(auction.active && block.timestamp >= auction.endTime, "Cannot end yet");
        
        auction.active = false;
        _nfts[nftId].isAuction = false;
        
        if (auction.highestBidder != address(0)) {
            NFTItem storage nft = _nfts[nftId];
            
            uint256 royaltyAmount = (auction.highestBid * nft.royalty) / 10000;
            uint256 platformAmount = (auction.highestBid * platformFee) / 10000;
            uint256 sellerAmount = auction.highestBid - royaltyAmount - platformAmount;
            
            _escrowBalances[nft.creator] += royaltyAmount;
            _escrowBalances[auction.seller] += sellerAmount;

            nft.owner = auction.highestBidder;
            nft.sold = true;
            
            _transfer(address(this), auction.highestBidder, nftId);
            emit AuctionEnded(nftId, auction.highestBidder, auction.highestBid);
            emit RoyaltyPaid(nftId, nft.creator, royaltyAmount);
        } else {
            _transfer(address(this), auction.seller, nftId);
            emit AuctionEnded(nftId, address(0), 0);
        }
    }

    function updatePrice(uint256 nftId, uint256 newPrice) 
        external 
        whenNotPaused 
        validNFT(nftId)
        onlyNFTOwner(nftId)
    {
        require(newPrice > 0, "Invalid price");
        require(_nfts[nftId].isListed, "NFT not listed");
        require(!_nfts[nftId].isAuction, "NFT is in auction");
        
        _nfts[nftId].price = newPrice;
        emit PriceUpdated(nftId, newPrice);
    }
    
    function cancelListing(uint256 nftId)
        external
        nonReentrant
        whenNotPaused
        validNFT(nftId)
        onlyNFTOwner(nftId)
    {
        require(_nfts[nftId].isListed, "NFT not listed");
        require(!_nfts[nftId].isAuction, "NFT is in auction");
        
        _nfts[nftId].isListed = false;
        _transfer(address(this), msg.sender, nftId);
        
        emit ListingCancelled(nftId, msg.sender);
    }
    

    
    function withdrawBalance() external nonReentrant {
        uint256 balance = _escrowBalances[msg.sender];
        require(balance > 0, "No balance");
        
        _escrowBalances[msg.sender] = 0;
        
        (bool success, ) = payable(msg.sender).call{value: balance}("");
        require(success, "Transfer failed");
        
        emit FundsWithdrawn(msg.sender, balance);
    }
    
    // View Functions
    

    function getNFT(uint256 nftId) external view returns (NFTItem memory) {
        NFTItem memory nft = _nfts[nftId];
        nft.owner = payable(ownerOf(nftId)); 
        return nft;
    }
    
    function getAuction(uint256 nftId) external view returns (Auction memory) {
        return _auctions[nftId];
    }
    
    function getEscrowBalance(address account) external view returns (uint256) {
        return _escrowBalances[account];
    }
    
    function getListingPrice() external view returns (uint256) {
        return listingPrice;
    }
    
    function getPlatformFee() external view returns (uint256) {
        return platformFee;
    }
    
    // Required overrides
    
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721URIStorage, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
