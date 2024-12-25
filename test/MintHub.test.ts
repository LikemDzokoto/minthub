import { expect } from "chai";
import { ethers } from "hardhat";
import { MintHub, MintHub__factory } from "../typechain-types";

import {time,loadFixture, } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { extendEnvironment } from "hardhat/config";


const price  = ethers.parseEther("0.001");
const  royalty = 500; //sample royalty of 5% express in basis points
const tokenURI = "https://testURI.com"

describe("MintHub Contract",function(){

    async function deployMintHubFixture(){
        const [owner,seller, buyer , bidder1 , bidder2] = await ethers.getSigners();
        const MintHub  = await ethers.getContractFactory("MintHub")
        const mintHub = await MintHub.deploy();

        // const mintTx  = await mintHub.createToken("https://testURI.com", price , royalty);

        return {mintHub , owner ,seller , buyer , bidder1 , bidder2};
    } 
    it("should deploy the minthub contract", async function(){
        const { mintHub ,owner} = await deployMintHubFixture();
        expect(mintHub).to.be.ok;   
        
    }); 
    describe("NFT Creation", function(){
        it("It should create a mintHub  and emit an event", async function() {
            const { mintHub, seller, buyer } = await loadFixture(deployMintHubFixture); 
            
            //log out MintHub Address 
            console.log("MintHub Address:", await mintHub.getAddress());

            await expect(mintHub.connect(seller).createToken(tokenURI, price,royalty,{
                value: price
            })            
        ) 
        .to.emit(mintHub , "MintHubItemCreated")
        .withArgs(1, seller.address,mintHub.getAddress(), price, false);

        const nft = await mintHub.fetchMintHubItem();
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

                const nft = await mintHub.fetchMintHubItem();
                expect(nft[0].price).to.equal(resalePrice);
                
            })
        });

        describe("Auction Operations", function(){
            it("It should allow the owner to start an auction", async function(){
                const { mintHub, seller } = await loadFixture(deployMintHubFixture);

                //mint the nft
            await mintHub.connect(seller).createToken(tokenURI, price, royalty, {
                value: price,
              });
            
              const ONE_HOUR = 3600;
              const startingBid = ethers.parseEther("0.5");
              
              const latestBlock = await ethers.provider.getBlock("latest");
              const auctionEndTime = (latestBlock?.timestamp ?? 0) + ONE_HOUR;

              
              await expect(
               mintHub.connect(seller).createAuction(1, startingBid, ONE_HOUR)
            )
              .to.emit(mintHub, "AuctionCreated")
              .withArgs(1, seller.address, startingBid, auctionEndTime);

              const auction = await mintHub.getAuction(1);
              //access auction details 
              console.log("Auction details", auction)
              expect(auction.active).to.be.true;
              expect(auction.seller).to.equal(seller.address);

        
            })
        })



    });

    
