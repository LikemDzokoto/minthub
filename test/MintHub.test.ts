import { expect } from "chai";
import { ethers } from "hardhat";
import { MintHub, MintHub__factory } from "../typechain-types";

import {time,loadFixture, } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { extendEnvironment } from "hardhat/config";


const price  = ethers.parseEther("0.001");
const  royalty = 500; //sample royalty of 5% express in basis points
const tokenURI = "https://testURI.com"

const ONE_HOUR = 3600; // Auction duration in seconds
const startingBid = ethers.parseEther("0.5");


describe("MintHub Contract",function(){

    async function deployMintHubFixture(){
        const [owner,seller, buyer , bidder1 , bidder2, bidder3] = await ethers.getSigners();
        const MintHub  = await ethers.getContractFactory("MintHub")
        const mintHub = await MintHub.deploy();

        // const mintTx  = await mintHub.createToken("https://testURI.com", price , royalty);

        return {mintHub , owner ,seller , buyer , bidder1 , bidder2 , bidder3};
    } 
    it("should deploy the minthub contract", async function(){
        const { mintHub ,owner} = await deployMintHubFixture();
        expect(mintHub).to.be.ok;    
        
    }); 
    describe("NFT Creation", function(){
        it("It should create a mintHub NFT  and emit an event", async function() {
            const { mintHub, seller, buyer } = await loadFixture(deployMintHubFixture); 
            
            //log out MintHub Address 
            console.log("MintHub Address:", await mintHub.getAddress());

            await expect(mintHub.connect(seller).createToken(tokenURI, price,royalty,{
                value: price
            })            
        ) 
        .to.emit(mintHub , "MintHubItemCreated")
        .withArgs(1, seller.address,mintHub.getAddress(), price, false);

        const nft = await mintHub.fetchMintHubItems();
        expect(nft.length).to.equal(1);
        expect(nft[0].nftId).to.equal(1);
        expect(nft[0].price).to.equal(price);
        });
    });
    describe("Token Resale", function(){
        it("It should allow the owner to resell the token", async function(){
            const { mintHub, seller, buyer } = await loadFixture(deployMintHubFixture);

            await mintHub.connect(seller).createToken(tokenURI, price, royalty, {
                value: ethers.parseEther("0.001"),
              });
        
              // Simulate buying the NFT
              await mintHub.connect(buyer).createMintHubItemSale(1, {
                value: price,
              });
        
              // Resell the NFT
              const resalePrice = ethers.parseEther("2");
                await expect(
                  mintHub.connect(buyer).resellToken(resalePrice, 1, {
                      value: ethers.parseEther("0.001"),
                  })
              )
                .to.emit(mintHub, "tokenResale")
                .withArgs(1, buyer.address, resalePrice);

                const nft = await mintHub.getMintHubItem(1);
                expect(nft.price).to.equal(resalePrice);
                
            })
            
        });
        
        describe("Direct Nft sale", function(){
        
            it("should allow an NFT to be sold directly without auction", async function () {
                const { mintHub, seller, buyer } = await loadFixture(deployMintHubFixture);
            
                // Mint the NFT
                await mintHub.connect(seller).createToken(tokenURI, price, royalty, {
                  value:price,
                });

                const nftBeforePurchase = await mintHub.getMintHubItem(1);
                console.log("NFT Item Details:",nftBeforePurchase);
            
                // Buyer purchases the NFT
                await expect(
                  mintHub.connect(buyer).createMintHubItemSale(1, {
                    value: price,
                  })
                )
                  .to.emit(mintHub, "mintHubItemSold")
                  .withArgs(1, seller.address, buyer.address, price);
            

               
                const nftAfterPurchase = await mintHub.getMintHubItem(1);
                console.log("NFT Item Details After Purchase:", nftAfterPurchase);

                
                expect(nftAfterPurchase.length).to.be.greaterThan(0); 
                expect(nftAfterPurchase.sold).to.be.true;
                expect(await mintHub.ownerOf(1)).to.equal(buyer.address);
              });

              it("should not allow purchasing an NFT with an incorrect price", async function() {
                const { mintHub, seller, buyer } = await loadFixture(deployMintHubFixture);
            
                // Mint the NFT
                await mintHub.connect(seller).createToken(tokenURI, price, royalty, {
                    value: price,
                });
            
                // Attempt to purchase the NFT with an incorrect price
                const incorrectPrice = ethers.parseEther("0.002"); // Set an incorrect price
                await expect(
                    mintHub.connect(buyer).createMintHubItemSale(1, {
                        value: incorrectPrice,
                    })
                ).to.be.revertedWith("incorrect pricing"); 
            });
            });

    

        describe("Auction Operations", function(){
            it("It should allow the owner of an nft to start an auction", async function(){
                const { mintHub, seller, buyer , bidder1} = await loadFixture(deployMintHubFixture);
                    

                const nft_price = ethers.parseEther("1");
                const listingPrice = ethers.parseEther("0.001");

                //mint the nft
            await mintHub.connect(seller).createToken(tokenURI, nft_price, royalty, {
                value: listingPrice,
              });

             // Simulate buying the NFT
                await mintHub.connect(buyer).createMintHubItemSale(1, {
                value: nft_price,
              }); 

                // Verify ownership after the sale
                const newOwner = await mintHub.ownerOf(1);
                console.log("owner of this token", newOwner);
                expect(newOwner).to.equal(buyer.address);

             
              
              //before auciton  check the ownership of the token    
              const ownerBeforeAuction = await mintHub.ownerOf(1);
               console.log("Owner of the token before auction:", ownerBeforeAuction);
              

               
            const tx = await mintHub.connect(buyer).createAuction(1, startingBid,ONE_HOUR);
            const receipt = await tx.wait();
            const block = await ethers.provider.getBlock(receipt?.blockNumber ?? 0 );   
            const auctionEndTime = (block?.timestamp ?? 0 ) + ONE_HOUR;
 
              
              await expect(tx )
              .to.emit(mintHub, "AuctionCreated")
              .withArgs(1 , buyer.address, startingBid, auctionEndTime);

              const auction = await mintHub.getAuction(1);
              //access auction details 
              console.log("Auction details", auction)
              expect(auction.active).to.be.true;        
              expect(auction.seller).to.equal(buyer.address);
              expect(auction.startingBid).to.equal(startingBid);
              expect(auction.endTime).to.equal(auctionEndTime)

            });





            it("it should not allow a non  owner to start an auction", async function(){
                const { mintHub, buyer } = await loadFixture(deployMintHubFixture);


                // Attempt to create an auction without owning the NFT
                await expect(
                  mintHub.connect(buyer).createAuction(1, startingBid, ONE_HOUR)
                ).to.be.revertedWith("only  owner  can create an auction");
              });





        
              it("should place a bid and emit BidPlaced event", async function () {
                const { mintHub, seller,buyer ,  bidder1, bidder2, bidder3 } = await loadFixture(deployMintHubFixture);
                


                // Mint the NFT
                await mintHub.connect(seller).createToken(tokenURI, price, royalty, {
                  value:  price,
                });
                 // Simulate buying the NFT
                 await mintHub.connect(buyer).createMintHubItemSale(1, {
                  value: price,
                }); 
  
                  // Verify ownership after the sale
                  const newOwner = await mintHub.ownerOf(1);
                  console.log("owner of this token", newOwner);
                  expect(newOwner).to.equal(buyer.address);
            
                // Create an auction
                await mintHub.connect(buyer).createAuction(1, startingBid, ONE_HOUR);


            
                // Simulate a live auction with multiple bids
                const bidAmount1 = ethers.parseEther("0.8");
                await expect(
                  mintHub.connect(bidder1).placeBid(1, {
                    value: bidAmount1,
                  })
                )
                  .to.emit(mintHub, "BidPlaced")
                  .withArgs(1, bidder1.address, bidAmount1);
            
                const bidAmount2 = ethers.parseEther("1.0");
                await expect(
                  mintHub.connect(bidder2).placeBid(1, {
                    value: bidAmount2,
                  })
                )
                  .to.emit(mintHub, "BidPlaced")
                  .withArgs(1, bidder2.address, bidAmount2);
            
                const bidAmount3 = ethers.parseEther("1.2");
                await expect(
                  mintHub.connect(bidder3).placeBid(1, {
                    value: bidAmount3,
                  })
                )
                  .to.emit(mintHub, "BidPlaced")
                  .withArgs(1, bidder3.address, bidAmount3);
            
                const auction = await mintHub.getAuction(1);
                expect(auction.highestBid).to.equal(bidAmount3);
                expect(auction.highestBidder).to.equal(bidder3.address);
              });


              it("should finalize an auction and emit AuctionFinalized event", async function () {
                const { mintHub,buyer,  seller, bidder1, bidder2, bidder3 } = await loadFixture(deployMintHubFixture);
            
               // Mint the NFT
               await mintHub.connect(seller).createToken(tokenURI, price, royalty, {
                value:  price,
              });

              
               // Simulate buying the NFT
               await mintHub.connect(buyer).createMintHubItemSale(1, {
                value: price,
              }); 
            
                // Create an auction
                await mintHub.connect(buyer).createAuction(1, startingBid, ONE_HOUR);
            
                // Simulate a live auction with multiple bids
                const bidAmount1 = ethers.parseEther("0.8");
                await mintHub.connect(bidder1).placeBid(1, {
                  value: bidAmount1,
                });
            
                const bidAmount2 = ethers.parseEther("1.0");
                await mintHub.connect(bidder2).placeBid(1, {
                  value: bidAmount2,
                });
            
                const bidAmount3 = ethers.parseEther("1.2");
                await mintHub.connect(bidder3).placeBid(1, {
                  value: bidAmount3,
                });
            
                // Fast-forward time
                await ethers.provider.send("evm_increaseTime", [3600]);
                await ethers.provider.send("evm_mine");
            
                // Finalize the auction
                await expect(mintHub.connect(seller).finalizeAuction(1))
                  .to.emit(mintHub, "AuctionFinalized")
                  .withArgs(1, bidder3.address, bidAmount3);
            
                const auction = await mintHub.getAuction(1);
                expect(auction.active).to.be.false;
              });
            });

        })
    


    
