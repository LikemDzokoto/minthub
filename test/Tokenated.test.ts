  import { expect } from "chai";
  import { ethers } from "hardhat";

  import {time,loadFixture, } from "@nomicfoundation/hardhat-toolbox/network-helpers";
  import { extendEnvironment } from "hardhat/config";

  const price = ethers.parseEther("0.001");
  const royalty = 500; // Royalty of 5% in basis points
  const tokenURI = "https://testURI.com";
  const ONE_HOUR = 3600;
  const startingBid = ethers.parseEther("0.5");
  const MIN_BID = ethers.parseEther("0.01");
  const newPrice = ethers.parseEther("2");


  describe("Tokenated Contract", function () {
    async function deployMintHubFixture() {
      const [owner, seller, buyer, bidder1, bidder2, bidder3 , buyer1 , buyer2] = await ethers.getSigners();
      const Tokenated = await ethers.getContractFactory("Tokenated");
      const tokenated = await Tokenated.deploy();
      return { tokenated, owner, seller, buyer, bidder1, bidder2, bidder3 , buyer1 , buyer2 };
    }

    it("should deploy the Tokenated contract successfully", async function () {
      const { tokenated } = await deployMintHubFixture();
      expect(tokenated).to.be.ok;
    });

    // NFT Creation Scenarios
    describe("NFT Creation", function () {
      it("should allow a user to mint an NFT and emit the correct event", async function () {
        const { tokenated, seller } = await deployMintHubFixture();

        await expect(
          tokenated.connect(seller).mintNFT(tokenURI, price, royalty, { value: price })
        )
          .to.emit(tokenated, "NFTListed")
          .withArgs(1, seller.address, price);

        const nft = await tokenated.getNFT(1);
        expect(nft.nftId).to.equal(1);
        expect(nft.price).to.equal(price);
        expect(nft.creator).to.equal(seller.address);
      });

      it("should not allow duplicate NFT minting", async function () {
        const { tokenated, seller } = await deployMintHubFixture();
        const tokenURI = "duplicateURI";
        
    
        await tokenated.connect(seller).mintNFT(tokenURI, price, royalty, { value: price })
    
        await expect(
            tokenated.connect(seller).mintNFT(tokenURI, price, royalty, { value: price })
        ).to.be.revertedWith("Token already minted");
    });

    it("should not allow minting with an empty token URI", async function () {
      const { tokenated, seller } = await deployMintHubFixture();

      await expect(
        tokenated.connect(seller).mintNFT("", price, royalty, { value: price })
    ).to.be.revertedWith("Empty URI");


    }
  )
    

      it("should not allow NFT minting with incorrect listing fee", async function () {
        const { tokenated, seller } = await deployMintHubFixture();

        await expect(
          tokenated.connect(seller).mintNFT(tokenURI, price, royalty, { value: ethers.parseEther("0.0005") })
        ).to.be.revertedWith("Incorrect listing fee");
      });
    });

    // Direct Sale Scenario
    describe("Direct NFT Sale", function () {
      it("should allow a direct sale of an NFT", async function () {
        const { tokenated, seller, buyer } = await deployMintHubFixture();

        await tokenated.connect(seller).mintNFT(tokenURI, price, royalty, { value: price });

        await expect(
          tokenated.connect(buyer).buyNFT(1, { value: price })
        )
          .to.emit(tokenated, "NFTSold")
          .withArgs(1, seller.address, buyer.address, price);

        const nft = await tokenated.getNFT(1);
        expect(nft.owner).to.equal(buyer.address);
      });

      it("should prevent double purchase of the same NFT", async function () {
       const { tokenated, seller, buyer, buyer1 ,buyer2 } = await deployMintHubFixture();
       await tokenated.connect(seller).mintNFT(tokenURI, price, royalty, { value:price});
    
        
        await tokenated.connect(buyer1).buyNFT(1, { value: price });
    
        await expect(
            tokenated.connect(buyer2).buyNFT(1, { value: price })
        ).to.be.revertedWith("NFT not available");
    });

      it("should revert when a buyer attempts to purchase with incorrect price", async function () {
        const { tokenated, seller, buyer } = await deployMintHubFixture();

        await tokenated.connect(seller).mintNFT(tokenURI, price, royalty, { value: price });

        await expect(
          tokenated.connect(buyer).buyNFT(1, { value: ethers.parseEther("0.002") })
        ).to.be.revertedWith("Incorrect price");
      });
    });

    it("should prevent blacklisted users from bidding or purchasing", async function () {
      const { tokenated,owner, seller, buyer  } = await deployMintHubFixture();
      await tokenated.connect(seller).mintNFT(tokenURI, price, royalty, { value:price});
      await tokenated.connect(owner).blackList(buyer.address);

      await expect(
        tokenated.connect(buyer).buyNFT(1, { value: price })
    ).to.be.revertedWith("address is blacklisted");

 
    await tokenated.connect(seller).createAuction(1,startingBid, 3600, ethers.parseEther("0.1"));

    await expect(
        tokenated.connect(buyer).placeBid(1, { value: ethers.parseEther("1.1") })
    ).to.be.revertedWith("address is blacklisted");

    })


    //Auction Operations
    describe("Auction Operations", function () {
      it("should allow the seller to start an auction", async function () {
        const { tokenated, seller } = await deployMintHubFixture();

        await tokenated.connect(seller).mintNFT(tokenURI, price, royalty, { value: price });


        const tx = await tokenated.connect(seller).createAuction(1, startingBid,ONE_HOUR, MIN_BID);
        const receipt = await tx.wait();
        const block = await ethers.provider.getBlock(receipt?.blockNumber ?? 0 );   
        const auctionEndTime = (block?.timestamp ?? 0 ) + ONE_HOUR;


        await expect(tx)
          .to.emit(tokenated, "AuctionCreated")
          .withArgs(1, seller.address, startingBid, auctionEndTime);

        const auction = await tokenated.getAuction(1);
        expect(auction.active).to.be.true;
      });

      it("should not allow a non-owner to start an auction", async function () {
        const { tokenated, seller, buyer } = await deployMintHubFixture();

        await tokenated.connect(seller).mintNFT(tokenURI, price, royalty, { value: price });

        

        await expect(
          tokenated.connect(buyer).createAuction(1, startingBid,ONE_HOUR, MIN_BID)
        ).to.be.revertedWith("Only the seller can create an auction");
      });

      it("should revert if the auction duration is invalid", async function () {
        const { tokenated, seller } = await deployMintHubFixture();
        await tokenated.connect(seller).mintNFT(tokenURI, price, royalty, { value: price });

        await expect(
          tokenated.connect(seller).createAuction(1, startingBid, 30, MIN_BID)
      ).to.be.revertedWith("Invalid duration");
  
      await expect(
          tokenated.connect(seller).createAuction(1, startingBid, 8 * 24 * 60 * 60, MIN_BID) 
      ).to.be.revertedWith("Invalid duration");
      }
    );

      it("should allow placing bids during an auction", async function () {
        const { tokenated, seller, bidder1, bidder2 } = await deployMintHubFixture();

        await tokenated.connect(seller).mintNFT(tokenURI, price, royalty, { value: price });

    

        await tokenated.connect(seller).createAuction(1, startingBid,ONE_HOUR, MIN_BID);

        await expect(
          tokenated.connect(bidder1).placeBid(1, { value: ethers.parseEther("0.8") })
        )
          .to.emit(tokenated, "BidPlaced")
          .withArgs(1, bidder1.address, ethers.parseEther("0.8"));

        await expect(
          tokenated.connect(bidder2).placeBid(1, { value: ethers.parseEther("1.0") })
        )
          .to.emit(tokenated, "BidPlaced")
          .withArgs(1, bidder2.address, ethers.parseEther("1.0"));
      });

      it("should allow bidding only during the auction duration", async function () {
        const {tokenated , seller , bidder1 , bidder2} = await deployMintHubFixture();
    
        await tokenated.connect(seller).mintNFT(tokenURI, price, royalty, { value: price });

        await tokenated.connect(seller).createAuction(1, startingBid, ONE_HOUR, MIN_BID);
    
        //  placing a bid within the duration
        await ethers.provider.send("evm_increaseTime", [1800]); 
        await tokenated.connect(bidder1).placeBid(1, { value: ethers.parseEther("1.1") });
    
        await ethers.provider.send("evm_increaseTime", [3600]); // Additional 1 hour
        await ethers.provider.send("evm_mine", []);
    
        //  no bids can be placed after the auction duration
        await expect(
            tokenated.connect(bidder2).placeBid(1, { value: ethers.parseEther("1.2") })
        ).to.be.revertedWith("Auction ended/invalid");
    });

      it("should finalize an auction correctly", async function () {
        const { tokenated, seller, bidder1 } = await deployMintHubFixture();

        await tokenated.connect(seller).mintNFT(tokenURI, price, royalty, { value: price });

        await tokenated.connect(seller).createAuction(1, startingBid,ONE_HOUR, MIN_BID);

        await tokenated.connect(bidder1).placeBid(1, { value: ethers.parseEther("0.8") });
        
        // Fast-forward time
        await ethers.provider.send("evm_increaseTime", [3600]);
        await ethers.provider.send("evm_mine");

        await expect(tokenated.connect(seller).finalizeAuction(1))
          .to.emit(tokenated, "AuctionEnded")
          .withArgs(1, bidder1.address, ethers.parseEther("0.8"));

        const nft = await tokenated.getNFT(1);
        expect(nft.owner).to.equal(bidder1.address);
      });
    });


    it("should allow the seller to cancel the auction before any bids", async function () {
      const { tokenated, seller, bidder1 } = await deployMintHubFixture();

      await tokenated.connect(seller).mintNFT(tokenURI, price, royalty, { value: price });
      await tokenated.connect(seller).createAuction(1, startingBid,ONE_HOUR, MIN_BID);
      
      await tokenated.connect(seller).cancelAuction(1);

      const nft = await tokenated.getNFT(1);
      const auction = await tokenated.getAuction(1);

      expect(nft.isAuction).to.equal(false);
      expect(auction.active).to.equal(false);
      expect(nft.owner).to.equal(seller.address);

    })

    it("should not allow the seller to cancel the auction after a bid has been placed", async function () {
      const { tokenated, seller, buyer} = await deployMintHubFixture();
      await tokenated.connect(seller).mintNFT(tokenURI, price, royalty, { value:price });
      await tokenated.connect(seller).createAuction(1, startingBid, ONE_HOUR, MIN_BID);

      await tokenated.connect(buyer).placeBid(1, { value: ethers.parseEther("1.5") });

      await expect(
          tokenated.connect(seller).cancelAuction(1)
      ).to.be.revertedWith("Cannot cancel after a bid has been placed");

    }
  )

    it("should not allow non-owners to cancel an auction", async function () {
      const { tokenated, seller, bidder1 ,buyer} = await deployMintHubFixture();
      await tokenated.connect(seller).mintNFT(tokenURI, price, royalty, { value: price });
      await tokenated.connect(seller).createAuction(1, startingBid,ONE_HOUR, MIN_BID);

      await expect(
        tokenated.connect(buyer).cancelAuction(1)
    ).to.be.revertedWith("Not NFT owner");
    })
  
    it("should allow users to withdraw their escrow balance", async function () {
      const { tokenated, seller, buyer } = await deployMintHubFixture();

     const platformFee = 250; 
  
    
      await tokenated.connect(seller).mintNFT(tokenURI, price, royalty, { value: price });
      await tokenated.connect(buyer).buyNFT(1, { value: price });
    
      const initialBalance = await ethers.provider.getBalance(seller.address);
    
      const royaltyAmount = (BigInt(price) * BigInt(royalty)) / BigInt(10000);
      const platformAmount = (BigInt(price) * BigInt(platformFee)) / BigInt(10000);
      const sellerAmount = BigInt(price) - royaltyAmount - platformAmount;
    
      await expect(tokenated.connect(seller).withdrawBalance())
        .to.emit(tokenated, "FundsWithdrawn")
        .withArgs(seller.address, sellerAmount); 
    
      const finalBalance = await ethers.provider.getBalance(seller.address);
      expect(finalBalance).to.be.above(initialBalance);
    });

    it("should allow the owner to update the price of a listed NFT", async function () {
      const { tokenated, seller } = await deployMintHubFixture();
      
      await tokenated.connect(seller).mintNFT(tokenURI, price, royalty, { value: price });
    
      await expect(tokenated.connect(seller).updatePrice(1, newPrice))
      .to.emit(tokenated, "PriceUpdated")
      .withArgs(1, newPrice);

      // Verify the new price
    const nft = await tokenated.getNFT(1);
    expect(nft.price.toString()).to.equal(newPrice.toString());
  });

  it("should not allow updating the price to zero or less", async function () {
    const { tokenated, seller } = await deployMintHubFixture();

    await tokenated.connect(seller).mintNFT(tokenURI, price, royalty, { value: price });
    await expect(tokenated.connect(seller).updatePrice(1, 0))
        .to.be.revertedWith("Invalid price");
  })

  it("should not allow updating the price of an unlisted NFT", async function () {
    const { tokenated, seller } = await deployMintHubFixture();
    await tokenated.connect(seller).mintNFT(tokenURI, price, royalty, { value:price})

    await tokenated.connect(seller).cancelListing(1);

    const newPrice = ethers.parseEther("2");
    await expect(tokenated.connect(seller).updatePrice(1, newPrice))
        .to.be.revertedWith("NFT not listed");
 
  })

  it("should not allow updating the price of an NFT in auction", async function () {
    const { tokenated, seller } = await deployMintHubFixture();

    await tokenated.connect(seller).mintNFT(tokenURI, price, royalty, { value: price });
    await tokenated.connect(seller).createAuction(1, ethers.parseEther("0.5"), 3600, ethers.parseEther("0.01"));

    const newPrice = ethers.parseEther("2");
    await expect(tokenated.connect(seller).updatePrice(1, newPrice))
        .to.be.revertedWith("NFT not listed ");
  })

  it("should not allow a non-owner to cancel a listing", async function () {
    const { tokenated, seller, buyer } = await deployMintHubFixture();
    await tokenated.connect(seller).mintNFT(tokenURI, price, royalty, { value: price });

    await expect(tokenated.connect(buyer).cancelListing(1))
    .to.be.revertedWith("Not NFT owner");

  })

  it("should not allow canceling an unlisted NFT", async function () {
    const { tokenated, seller } = await deployMintHubFixture();
    await tokenated.connect(seller).mintNFT(tokenURI, price, royalty, { value:price});

    await tokenated.connect(seller).cancelListing(1);

    await expect(tokenated.connect(seller).cancelListing(1))
        .to.be.revertedWith("NFT not listed");
  })

  it("should not allow canceling a listing for an NFT in auction", async function () {
    const { tokenated, seller } = await deployMintHubFixture();

    await tokenated.connect(seller).mintNFT(tokenURI, price, royalty, { value:price});
    await tokenated.connect(seller).createAuction(1, ethers.parseEther("0.5"), 3600, ethers.parseEther("0.01"));


    await expect(tokenated.connect(seller).cancelListing(1))
        .to.be.revertedWith("NFT not listed");
  })

  

  });
