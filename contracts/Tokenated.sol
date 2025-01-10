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
    }
    
    struct Auction {
        uint256 nftId;
        address payable seller;
        uint256 startingBid;
        uint256 highestBid;
        address payable highestBidder;
        uint256 endTime;
        bool active;
    }
    
    mapping(uint256 => NFTItem) private _nfts;
    mapping(uint256 => Auction) private _auctions;
    mapping(address => uint256) private _escrowBalances;
    // mapping(uint256 => address) private nftOwners;
    
    event NFTListed(uint256 indexed nftId, address seller, uint256 price);
    event NFTSold(uint256 indexed nftId, address seller, address buyer, uint256 price);
    event AuctionCreated(uint256 indexed nftId, address seller, uint256 startingBid, uint256 endTime);
    event BidPlaced(uint256 indexed nftId, address bidder, uint256 amount);
    event AuctionEnded(uint256 indexed nftId, address winner, uint256 amount);
    event RoyaltyPaid(uint256 indexed nftId, address creator, uint256 amount);
    event FeeUpdated(string feeType, uint256 newAmount);
    event FundsWithdrawn(address indexed recipient, uint256 amount);
    
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
        require(msg.value == listingPrice, "Incorrect listing fee");
        require(royalty <= 1000, "Royalty cannot exceed 10%");
        
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
            isAuction: false
        });
        
        
        
        emit NFTListed(newNftId, msg.sender, price);
        
        return newNftId;
    }
    
    function buyNFT(uint256 nftId) 
        external 
        payable 
        nonReentrant 
        whenNotPaused 
    {
        NFTItem storage nft = _nfts[nftId];
         
        require(!nft.sold && !nft.isAuction, "NFT not available");
        require(msg.value == nft.price, "Incorrect price");

        

        
        uint256 royaltyAmount = (msg.value * nft.royalty) / 10000;
        uint256 platformAmount = (msg.value * platformFee) / 10000;
        uint256 sellerAmount = msg.value - royaltyAmount - platformAmount;
        
        _escrowBalances[nft.creator] += royaltyAmount;
        _escrowBalances[nft.seller] += sellerAmount;
        
        nft.sold = true;
        nft.owner = payable(msg.sender);
        
        _transfer(address(this), msg.sender, nftId);
        emit NFTSold(nftId, nft.seller, msg.sender, msg.value);
        emit RoyaltyPaid(nftId, nft.creator, royaltyAmount);
    }
    
    function createAuction(uint256 nftId, uint256 startingBid, uint256 duration)
        external
        whenNotPaused
    {
        
        require(_nfts[nftId].seller == msg.sender || _nfts[nftId].owner == payable(address(this)), "Not owner");
    
        require(duration > 0 && duration <= 7 days, "Invalid duration");
        
        _transfer(msg.sender, address(this), nftId);
        
        _auctions[nftId] = Auction({
            nftId: nftId,
            seller: payable(msg.sender),
            startingBid: startingBid,
            highestBid: 0,
            highestBidder: payable(address(0)),
            endTime: block.timestamp + duration,
            active: true
        });
        
        _nfts[nftId].isAuction = true;
        
        emit AuctionCreated(nftId, msg.sender, startingBid, block.timestamp + duration);
    }
    
    function placeBid(uint256 nftId)
        external
        payable
        nonReentrant
        whenNotPaused
    {
        Auction storage auction = _auctions[nftId];
        require(auction.active && block.timestamp < auction.endTime, "Auction ended/invalid");
        require(msg.value > auction.highestBid && msg.value >= auction.startingBid, "Bid too low");
        
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
            
            _transfer(address(this), auction.highestBidder, nftId);
            emit AuctionEnded(nftId, auction.highestBidder, auction.highestBid);
            emit RoyaltyPaid(nftId, nft.creator, royaltyAmount);
        } else {
            _transfer(address(this), auction.seller, nftId);
            emit AuctionEnded(nftId, address(0), 0);
        }
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
        return _nfts[nftId];
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
