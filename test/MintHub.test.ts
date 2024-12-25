import { expect } from "chai";
import { ethers } from "hardhat";

import {time,loadFixture, } from "@nomicfoundation/hardhat-toolbox/network-helpers";

describe("MintHub Contract",function(){

    async function deployFixture(){
        const [owner, addr1 , addr2] = await ethers.getSigners();
        const MintHub  = await ethers.getContractFactory("MintHub")
        const mintHub = await MintHub.deploy();


        const price  = ethers.parseEther("0.1");
        const  royalty = 500; //sample royalty of 5% express in basis points

        const mintTx  = await mintHub.createToken('https://game.example/item-id-1.json', price , royalty);

        return {mintHub , owner , addr1 , addr2};
    }
    it("should deploy the minthub contract", async function(){
        const { mintHub ,owner} = await deployFixture();
        expect(mintHub).to.be.ok;    
        
    });

} );