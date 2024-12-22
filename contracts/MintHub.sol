// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.28;


import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";



contract MintHub is ERC721URIStorage {
     using Counters for Counters.Counter;
     Counters.Counter private _nftId;
     Counters.Counter private _soldItems;



    address payable private owner;


     


    struct mintItem{
        uint256 _nftid;
        uint256 tokenId;
        address nftContract;
        address payable creator;
        address payable seller;
        address payable owner;
        uint256 price;
        bool sold;

        }

     /* =========== MAPPINGS ============ */

     mapping(uint256 => mintItem) private idToMintHubItem ;


      /* =========== EVENTS ============ */
      event MarketplaceItemCreated(
        uint256 indexed _nftId,
        address indexed nftContract,
        uint256 indexed tokenId,
        address creator,
        address seller,
        address owner,
        uint256 price,
        bool sold
    );


     /* =========== CONSTRUCTOR ============ */


    // constructor() {
    //     owner = payable(msg.sender);
    // }

    constructor() ERC721("MintHub Token", "MHT") {
      owner = payable(msg.sender);
    }










    
}
