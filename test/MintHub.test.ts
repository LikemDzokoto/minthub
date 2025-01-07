import { expect } from "chai";
import { ethers } from "hardhat";

import {time,loadFixture, } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { extendEnvironment } from "hardhat/config";

const price = ethers.parseEther("0.001");
const royalty = 500; // Royalty of 5% in basis points
const tokenURI = "https://testURI.com";
const ONE_HOUR = 3600; // Auction duration in seconds
const startingBid = ethers.parseEther("0.5");

describe("MintHub Contract", function () {
  async function deployMintHubFixture() {
    const [owner, seller, buyer, bidder1, bidder2, bidder3] = await ethers.getSigners();
    const MintHub = await ethers.getContractFactory("MintHub");
    const mintHub = await MintHub.deploy();
    return { mintHub, owner, seller, buyer, bidder1, bidder2, bidder3 };
  }

  it("should deploy the MintHub contract successfully", async function () {
    const { mintHub } = await deployMintHubFixture();
    expect(mintHub).to.be.ok;
  });

  // NFT Creation Scenarios
  describe("NFT Creation", function () {
    it("should allow a user to mint an NFT and emit the correct event", async function () {
      const { mintHub, seller } = await deployMintHubFixture();

      await expect(
        mintHub.connect(seller).mintNFT(tokenURI, price, royalty, { value: price })
      )
        .to.emit(mintHub, "NFTListed")
        .withArgs(1, seller.address, price);

      const nft = await mintHub.getNFT(1);
      expect(nft.nftId).to.equal(1);
      expect(nft.price).to.equal(price);
      expect(nft.creator).to.equal(seller.address);
    });

    it("should not allow NFT minting with incorrect listing fee", async function () {
      const { mintHub, seller } = await deployMintHubFixture();

      await expect(
        mintHub.connect(seller).mintNFT(tokenURI, price, royalty, { value: ethers.parseEther("0.0005") })
      ).to.be.revertedWith("Incorrect listing fee");
    });
  });

  // Direct Sale Scenarios
  describe("Direct NFT Sale", function () {
    it("should allow a direct sale of an NFT", async function () {
      const { mintHub, seller, buyer } = await deployMintHubFixture();

      await mintHub.connect(seller).mintNFT(tokenURI, price, royalty, { value: price });

      await expect(
        mintHub.connect(buyer).buyNFT(1, { value: price })
      )
        .to.emit(mintHub, "NFTSold")
        .withArgs(1, seller.address, buyer.address, price);

      const nft = await mintHub.getNFT(1);
      expect(nft.owner).to.equal(buyer.address);
    });

    it("should revert when a buyer attempts to purchase with incorrect price", async function () {
      const { mintHub, seller, buyer } = await deployMintHubFixture();

      await mintHub.connect(seller).mintNFT(tokenURI, price, royalty, { value: price });

      await expect(
        mintHub.connect(buyer).buyNFT(1, { value: ethers.parseEther("0.002") })
      ).to.be.revertedWith("Incorrect price");
    });
  });

 
  describe("Auction Operations", function () {
    it("should allow the owner to start an auction", async function () {
      const { mintHub, seller } = await deployMintHubFixture();

      await mintHub.connect(seller).mintNFT(tokenURI, price, royalty, { value: price });


      

      const tx = await mintHub.connect(seller).createAuction(1, startingBid,ONE_HOUR);
      const receipt = await tx.wait();
      const block = await ethers.provider.getBlock(receipt?.blockNumber ?? 0 );   
      const auctionEndTime = (block?.timestamp ?? 0 ) + ONE_HOUR;


      await expect(tx)
        .to.emit(mintHub, "AuctionCreated")
        .withArgs(1, seller.address, startingBid, auctionEndTime);

      const auction = await mintHub.getAuction(1);
      expect(auction.active).to.be.true;
    });

    it("should not allow a non-owner to start an auction", async function () {
      const { mintHub, seller, buyer } = await deployMintHubFixture();

      await mintHub.connect(seller).mintNFT(tokenURI, price, royalty, { value: price });

      await expect(
        mintHub.connect(buyer).createAuction(1, startingBid, ONE_HOUR)
      ).to.be.revertedWith("Not owner");
    });

    it("should allow placing bids during an auction", async function () {
      const { mintHub, seller, bidder1, bidder2 } = await deployMintHubFixture();

      await mintHub.connect(seller).mintNFT(tokenURI, price, royalty, { value: price });
      await mintHub.connect(seller).createAuction(1, startingBid, ONE_HOUR);

      await expect(
        mintHub.connect(bidder1).placeBid(1, { value: ethers.parseEther("0.8") })
      )
        .to.emit(mintHub, "BidPlaced")
        .withArgs(1, bidder1.address, ethers.parseEther("0.8"));

      await expect(
        mintHub.connect(bidder2).placeBid(1, { value: ethers.parseEther("1.0") })
      )
        .to.emit(mintHub, "BidPlaced")
        .withArgs(1, bidder2.address, ethers.parseEther("1.0"));
    });

    it("should finalize an auction correctly", async function () {
      const { mintHub, seller, bidder1 } = await deployMintHubFixture();

      await mintHub.connect(seller).mintNFT(tokenURI, price, royalty, { value: price });
      await mintHub.connect(seller).createAuction(1, startingBid, ONE_HOUR);

      await mintHub.connect(bidder1).placeBid(1, { value: ethers.parseEther("0.8") });
      
       // Fast-forward time
       await ethers.provider.send("evm_increaseTime", [3600]);
        await ethers.provider.send("evm_mine");

      await expect(mintHub.connect(seller).finalizeAuction(1))
        .to.emit(mintHub, "AuctionEnded")
        .withArgs(1, bidder1.address, ethers.parseEther("0.8"));

      const nft = await mintHub.getNFT(1);
      expect(nft.owner).to.equal(bidder1.address);
    });
  });

  // Escrow Balance Withdrawal
  describe("Escrow Balance", function () {
    it("should allow users to withdraw their escrow balance", async function () {
      const { mintHub, seller, buyer } = await deployMintHubFixture();

      await mintHub.connect(seller).mintNFT(tokenURI, price, royalty, { value: price });
      await mintHub.connect(buyer).buyNFT(1, { value: price });

      const initialBalance = await ethers.provider.getBalance(seller.address);

      await expect(mintHub.connect(seller).withdrawBalance())
        .to.emit(mintHub, "FundsWithdrawn")
        .withArgs(seller.address, price);

      const finalBalance = await ethers.provider.getBalance(seller.address);
      expect(finalBalance).to.be.above(initialBalance);
    });
  });
});
