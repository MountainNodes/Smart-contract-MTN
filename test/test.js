const Mountain = artifacts.require("Mountain");
const { time, BN , expectRevert} = require('@openzeppelin/test-helpers');
const { assertion } = require('@openzeppelin/test-helpers/src/expectRevert');
const Pair = artifacts.require('Pair.sol');
const Router = artifacts.require('Router.sol');

contract("Simulation", async accounts => {


    let owner = accounts[0];
    let alice = accounts[1];
    let bob = accounts[2];
    let jack = accounts[3];
    
    let rewardPool= accounts[6];
    let treasuryPool= accounts[7];
    let liquidityPool = accounts[8];
    let teamPool = accounts[9];

    let referral = "0x0000000000000000000000000000000000000000"; // Bytes20 same size as address

	let MountainToken;
    let router;
    let pair;


    let current_time = 0;

    

    before('Initial Setup', async () => {

        // TODO : manage current time to avoid Trader Joe expired errors

        MountainToken = await Mountain.deployed();
        

        // treasuryPool = await MountainToken.treasuryPool.call();   
        // rewardPool = await MountainToken.rewardPool.call();   
        // liquidityPool = await MountainToken.liquidityPool.call();  
        

        // Create Liquidity pair (MTN-AVAX)
        // await MountainToken.createPair.sendTransaction({from:owner, gas:8000000,});          

        await MountainToken.openTrading.sendTransaction({from:owner})

        // Add initial liquidity
        const pair_address = await MountainToken.traderJoePair.call();          
        pair = await Pair.at(pair_address);

        // 0x2D99ABD9008Dc933ff5c0CD271B88309593aB921 // TraderJoe testnet
        // 0x60aE616a2155Ee3d9A68541Ba4544862310933d4 // TraderJoe MainNet
        // 0x2D99ABD9008Dc933ff5c0CD271B88309593aB921 // Pangolin testnet
        router = await Router.at('0x60aE616a2155Ee3d9A68541Ba4544862310933d4');
    
        
        // Owner adds liquidity => Need to approve
        token_to_add = web3.utils.toWei('100000');
        await MountainToken.approve.sendTransaction(router.address, token_to_add,
        							{
        					            from: owner,
        					            gas: 4000000,
              						});
            
        console.log('erc20 approved');       
            
    
        
        // Owner adds liquidity 1AVAX, 10000 token
        await router.addLiquidityAVAX(
        				MountainToken.address,
        		        token_to_add,
        	            "0",
                        "0", 
        		        owner,
        		        Math.floor(Date.now() / 1000) + 60 * 60,
        		        {
        		            from: owner,
        		            gas: 4000000,
                			value: web3.utils.toWei('0.1')
          				});
         console.log('liquidity added');
            
        
        // Get the balance of LP of the owner
        balance = await pair.balanceOf(owner); 
        console.log(`balance LP owner : ${web3.utils.fromWei(balance)}`); 
          

      });




      async function printPoolBalances() {
       
        let balance_SC_Avax = await web3.eth.getBalance(MountainToken.address);
        let balance_SC_LP = await pair.balanceOf(MountainToken.address)
        let balance_SC_MNT = await MountainToken.balanceOf(MountainToken.address) 
        console.log(`balance SC AVAX: ${web3.utils.fromWei(balance_SC_Avax)}`); 
        console.log(`balance SC LP: ${web3.utils.fromWei(balance_SC_LP)}`); 
        console.log(`balance SC MNT: ${web3.utils.fromWei(balance_SC_MNT)}`); 


        let balance_RP_Avax = await web3.eth.getBalance(rewardPool);
        let balance_RP_LP = await pair.balanceOf(rewardPool)
        let balance_RP_MNT = await MountainToken.balanceOf(rewardPool) 
        console.log(`balance Reward Pool AVAX: ${web3.utils.fromWei(balance_RP_Avax)}`); 
        console.log(`balance Reward Pool LP: ${web3.utils.fromWei(balance_RP_LP)}`); 
        console.log(`balance Reward Pool MNT: ${web3.utils.fromWei(balance_RP_MNT)}`); 


        let balance_TP_Avax = await web3.eth.getBalance(treasuryPool);
        let balance_TP_LP = await pair.balanceOf(treasuryPool)
        let balance_TP_MNT = await MountainToken.balanceOf(treasuryPool) 
        console.log(`balance Treasury Pool AVAX: ${web3.utils.fromWei(balance_TP_Avax)}`); 
        console.log(`balance Treasury Pool LP: ${web3.utils.fromWei(balance_TP_LP)}`); 
        console.log(`balance Treasury Pool MNT: ${web3.utils.fromWei(balance_TP_MNT)}`); 


        let balance_LP_Avax = await web3.eth.getBalance(liquidityPool);
        let balance_LP_LP = await pair.balanceOf(liquidityPool)
        let balance_LP_MNT = await MountainToken.balanceOf(liquidityPool) 
        console.log(`balance Liquidity Pool AVAX: ${web3.utils.fromWei(balance_LP_Avax)}`); 
        console.log(`balance Liquidity Pool LP: ${web3.utils.fromWei(balance_LP_LP)}`); 
        console.log(`balance Liquidity Pool MNT: ${web3.utils.fromWei(balance_LP_MNT)}`);


        let balance_team_Avax = await web3.eth.getBalance(teamPool);
        let balance_team_LP = await pair.balanceOf(teamPool)
        let balance_team_MNT = await MountainToken.balanceOf(teamPool) 
        console.log(`balance team Pool AVAX: ${web3.utils.fromWei(balance_team_Avax)}`); 
        console.log(`balance team Pool LP: ${web3.utils.fromWei(balance_team_LP)}`); 
        console.log(`balance team Pool MNT: ${web3.utils.fromWei(balance_team_MNT)}`);        

    };   


    it ("prints the balances of all pools and the SC", async() => {
        await printPoolBalances();
    })


    async function buyMNT(buyer, tokenAmount) {
    
    	   
	    var path = new Array(2);

        path[0] = await router.WAVAX(); 
        path[1] = MountainToken.address;


	    
	    var amounts = await router.getAmountsIn.call(tokenAmount, path);
		var necessaryAVAX = parseInt(amounts[0].valueOf()).toString();
	     
        
		await router.swapAVAXForExactTokens(
			tokenAmount,
	        path,
            buyer,
            Math.floor(Date.now() / 1000) + 60 * 60 + current_time, {
            	from: buyer,
            	value: necessaryAVAX+1 // Add one to avoid EXCESSIVE_INPUT_AMOUNT error 
            });    
    
    } 



    async function sellMNT(seller, tokenAmount) {
    
    	//(if seller == owner : doesn't pay taxes)   

	    var path = new Array(2);

        path[0] = MountainToken.address;
        path[1] = await router.WAVAX(); 


		var MNT_to_approve = web3.utils.toWei("5000");


        await MountainToken.approve.sendTransaction(router.address, MNT_to_approve,
              {
                from: seller,
                gas: 4000000
              });

        console.log('MTN approved');   


	    var amounts = await router.getAmountsOut.call(tokenAmount, path);
        let withoufee = new BN(70)
        let denominator = new BN(100)

       

        //outputAfterTaxes = Math.floor(withoufee*amounts[1]/denominator) // Simulate higher slippage

        // Why The Fuck this function doesn't work !!!
        await router.swapExactTokensForAVAXSupportingFeeOnTransferTokens(
            tokenAmount,
            0,
            path,
            seller,
            Math.floor(Date.now() / 1000) + 10*60 + current_time,
                    {
                        from: seller,
                        gas: 6000000						          
                    });    

        console.log('MTN sold');   



    }     

    it("Alice buys token on TraderJoe", async() => {

		
		balance = await MountainToken.balanceOf.call(alice);
		console.log(`Balance of alice before : ${web3.utils.fromWei(balance)}`); 
		
		
        // 5 MNT
		var MNT_to_buy = web3.utils.toWei("200");
		await buyMNT(alice, MNT_to_buy);

		balance = await MountainToken.balanceOf.call(alice);
		console.log(`Balance of alice after : ${web3.utils.fromWei(balance)}`); 

    }); 
    
    // it("Alice sells token to Bob", async() => {

		
	// 	balance = await MountainToken.balanceOf.call(alice);
	// 	console.log(`Balance of alice before : ${web3.utils.fromWei(balance)}`); 

    //     balance = await MountainToken.balanceOf.call(bob);
	// 	console.log(`Balance of bob before : ${web3.utils.fromWei(balance)}`); 

	// 	balance = await web3.eth.getBalance(alice);
	// 	console.log(`Balance of alice before : ${web3.utils.fromWei(balance)}`);           
		
		
    //     // 5 MNT
	// 	var tokenAmount = web3.utils.toWei("500");


    //     await MountainToken.transfer(bob, tokenAmount, {from: alice,gas:1000000})

	// 	balance = await MountainToken.balanceOf.call(alice);
	// 	console.log(`Balance of alice after : ${web3.utils.fromWei(balance)}`); 

	// 	balance = await MountainToken.balanceOf.call(bob);
	// 	console.log(`Balance of bob after : ${web3.utils.fromWei(balance)}`);         

	// 	balance = await web3.eth.getBalance(alice);
	// 	console.log(`Balance of alice after : ${web3.utils.fromWei(balance)}`);         

    // });   
    
    // it("Alice sells token on TraderJoe", async() => {

		
	// 	balance = await MountainToken.balanceOf.call(alice);
	// 	console.log(`Balance of alice before : ${web3.utils.fromWei(balance)}`); 

	// 	balance = await web3.eth.getBalance(alice);
	// 	console.log(`Balance of alice before : ${web3.utils.fromWei(balance)}`);           
		
		
    //     // 5 MNT
	// 	var MNT_to_buy = web3.utils.toWei("500");
	// 	await sellMNT(alice, MNT_to_buy)

	// 	balance = await MountainToken.balanceOf.call(alice);
	// 	console.log(`Balance of alice after : ${web3.utils.fromWei(balance)}`); 

	// 	balance = await web3.eth.getBalance(alice);
	// 	console.log(`Balance of alice after : ${web3.utils.fromWei(balance)}`);         

    // });          


    it(" Alice creates a node of type 3 (Lava)", async () => {
           

        balance = await MountainToken.balanceOf(alice)
		console.log(`Balance of alice before : ${web3.utils.fromWei(balance)}`); 

        let priceTobePaid = web3.utils.toWei('20')


        await MountainToken.createNodeAndTransferToPools.sendTransaction(priceTobePaid, 2, referral, {
            from: alice,
            gas: 4000000,
          });

        balance = await MountainToken.balanceOf(alice)
		console.log(`Balance of alice after : ${web3.utils.fromWei(balance)}`); 

    });  
    
    
    it("Bob buys token on TraderJoe and create a node of type 2", async() => {

		

        // 15 MNT
		var MNT_to_buy = web3.utils.toWei('15');
		await buyMNT(bob, MNT_to_buy);

    
        await MountainToken.createNodeAndTransferToPools.sendTransaction(MNT_to_buy, 1, referral,{
            from: bob,
            gas: 4000000,
          });        

    });  


    it ("prints the balances of all pools and the SC", async() => {
        await printPoolBalances();
    })





 


    
    it(" gets node information", async () => {
           

        // 1 day has passed 
        current_time+=1*60*60*24
        await time.increase(current_time);


        numberOfNodes = await MountainToken.numberOfNodes()

        accountNodes_alice = await MountainToken.accountNodes(alice,0)
        nodeMapping_alice = await MountainToken.nodeMapping(accountNodes_alice)
        nodeReward_alice = await MountainToken.calculateRewards(accountNodes_alice)


        accountNodes_bob = await MountainToken.accountNodes(bob,0)
        nodeMapping_bob = await MountainToken.nodeMapping(accountNodes_bob)
        nodeReward_bob = await MountainToken.calculateRewards(accountNodes_bob)        




        console.log(`numberOfNodes : ${numberOfNodes}`); 
        console.log(`accountNodes alice: ${accountNodes_alice}`); 
        console.log(`nodeMapping alice: ${nodeMapping_alice}`); 
        console.log(`nodeReward alice: ${nodeReward_alice}`); 
        console.log(`accountNodes bob: ${accountNodes_bob}`); 
        console.log(`nodeMapping bob: ${nodeMapping_bob}`); 
        console.log(`nodeReward bob: ${nodeReward_bob}`);     
        
    
    });     


   
    it("Bob buys token on TraderJoe and create a node of type 3", async() => {

		

        // 20 MNT
		var MNT_to_buy = web3.utils.toWei('20');
		await buyMNT(bob, MNT_to_buy);

    
        await MountainToken.createNodeAndTransferToPools.sendTransaction(MNT_to_buy, 2,referral, {
            from: bob,
            gas: 4000000,
          });        

    });  


    
    it ("prints the balances of all pools and the SC", async() => {
        await printPoolBalances();
    }) 


    it("Bob claims rewards", async() => {

    
        await MountainToken.claimAllRewards.sendTransaction({
           from: bob,
           gas: 4000000,
         }); 

         balance = await MountainToken.balanceOf(bob)
         console.log(`Balance of bob after : ${web3.utils.fromWei(balance)}`); 


   });  
   
   
   it("updates pool addresses and fails", async() => {

       newTreasury = accounts[6];
       newReward = accounts[7];
       newLiquidity = accounts[8];

       await expectRevert(MountainToken.updateTreasuryWallet.sendTransaction(newTreasury,{
           from: bob, 
           gas: 4000000,
       }), "Ownable: caller is not the owner");

       await expectRevert(MountainToken.updateRewardWallet.sendTransaction(newReward,{
        from: alice, 
        gas: 4000000,
        }), "Ownable: caller is not the owner");
    
    await expectRevert(MountainToken.updateLiquidityWallet.sendTransaction(newLiquidity,{
        from: bob, 
        gas: 4000000,
        }), "Ownable: caller is not the owner");    
   })


//    it("updates pool addresses and succeeds", async() => {

//     treasuryPool = accounts[6];
//     rewardPool = accounts[7];
//     liquidityPool = accounts[8];

//     await MountainToken.updateTreasuryWallet.sendTransaction(treasuryPool,{
//         from: owner, 
//         gas: 4000000,
//     });

//     await MountainToken.updateRewardWallet.sendTransaction(rewardPool,{
//      from: owner, 
//      gas: 4000000,
//      });
 
//     await MountainToken.updateLiquidityWallet.sendTransaction(liquidityPool,{
//         from: owner, 
//         gas: 4000000,
//         });    
//      })  
     
     
    // it("updates fees and fails " , async() => {


    //     await expectRevert(MountainToken.updateRewardsFee.sendTransaction(10,{
    //         from: alice, 
    //         gas: 4000000,
    //     }), "Ownable: caller is not the owner");

    //     await expectRevert(MountainToken.updateLiquiditFee.sendTransaction(10,{
    //         from: bob, 
    //         gas: 4000000,
    //     }), "Ownable: caller is not the owner");
        
    //     await expectRevert(MountainToken.updateTreasuryFee.sendTransaction(10,{
    //         from: alice, 
    //         gas: 4000000,
    //     }), "Ownable: caller is not the owner");
        
    //     await expectRevert(MountainToken.updateClaimFee.sendTransaction(10,{
    //         from: bob, 
    //         gas: 4000000,
    //     }), "Ownable: caller is not the owner");
        
    //     await expectRevert(MountainToken.updateSellFee.sendTransaction(10,{
    //         from: alice, 
    //         gas: 4000000,
    //     }), "Ownable: caller is not the owner");
        
    //     await expectRevert(MountainToken.updateRewardSwapRatio.sendTransaction(10,{
    //         from: bob, 
    //         gas: 4000000,
    //     }), "Ownable: caller is not the owner");        
    // })

    // it("updates fees and succeeds ", async() => {
 

    //     await MountainToken.updateRewardsFee.sendTransaction(10,{
    //         from: owner, 
    //         gas: 4000000,
    //     });

    //     await MountainToken.updateLiquiditFee.sendTransaction(10,{
    //         from: owner, 
    //         gas: 4000000,
    //     });
        
    //     await MountainToken.updateTreasuryFee.sendTransaction(10,{
    //         from: owner, 
    //         gas: 4000000,
    //     });
        
    //     await MountainToken.updateClaimFee.sendTransaction(100,{
    //         from: owner, 
    //         gas: 4000000,
    //     });
        
    //     await MountainToken.updateSellFee.sendTransaction(10,{
    //         from: owner, 
    //         gas: 4000000,
    //     });
        
    //     await MountainToken.updateRewardSwapRatio.sendTransaction(10,{
    //         from: owner, 
    //         gas: 4000000,
    //     });     
    // }) 
    
    it ("prints the balances of all pools and the SC", async() => {
        await printPoolBalances();
    }) 


    it("Jack buys token on TraderJoe and create a node of type 3 but fails", async() => {

		

        // 25 MNT
		var MNT_to_buy = web3.utils.toWei('10');
		await buyMNT(jack, MNT_to_buy);

    
        await expectRevert(MountainToken.createNodeAndTransferToPools.sendTransaction(MNT_to_buy, 2,referral, {
            from: jack,
            gas: 4000000,
          }), "Node amount not correct.");        

    });  



    it("Jack claims rewards but fails", async() => {

    
        await expectRevert(MountainToken.claimAllRewards.sendTransaction({
           from: jack,
           gas: 4000000,
         }), "Must own nodes to claim rewards."); 

         balance = await MountainToken.balanceOf(jack)
         console.log(`Balance of jack after : ${web3.utils.fromWei(balance)}`); 


   });  

   it("Jack create a node of type 2", async() => {

		

    // 25 MNT
    var MNT_to_buy = web3.utils.toWei('15');
    await buyMNT(jack, MNT_to_buy);


    await MountainToken.createNodeAndTransferToPools.sendTransaction(MNT_to_buy, 1, referral,{
        from: jack,
        gas: 4000000,
    }); 

    balance = await MountainToken.balanceOf(jack)
    console.log(`Balance of jack after : ${web3.utils.fromWei(balance)}`); 
    
    }); 



    it("Jack creates 4 nodes of type 3", async() => {

		

        // 20 MNT
        var MNT_to_buy = web3.utils.toWei('80');
        await buyMNT(jack, MNT_to_buy);
        var node_price = web3.utils.toWei('20');


    
        await MountainToken.createNodeAndTransferToPools.sendTransaction(node_price, 2, referral,{
            from: jack,
            gas: 4000000,
        });   
        
        await MountainToken.createNodeAndTransferToPools.sendTransaction(node_price, 2, referral,{
            from: jack,
            gas: 4000000,
        });   
        
        await MountainToken.createNodeAndTransferToPools.sendTransaction(node_price, 2, referral,{
            from: jack,
            gas: 4000000,
        });   
        
        await MountainToken.createNodeAndTransferToPools.sendTransaction(node_price, 2, referral,{
            from: jack,
            gas: 4000000,
        });           

    });

   
    
    
    it("Jack observe infos about his nodes", async() => {
        
        // 1 day has passed again 
        let one_day = 60*60*24
        await time.increase(one_day);
        current_time+=one_day


        numberOfNodes = await MountainToken.numberOfNodes()
        console.log(numberOfNodes.toString())

        number_Nodes_jack = await MountainToken.getNumberOfNodes(jack)

        console.log(number_Nodes_jack.toString())

        for (i=0;i<number_Nodes_jack;i++) {
            accountNodes_jack = await MountainToken.accountNodes(jack,i)
            nodeMapping_jack = await MountainToken.nodeMapping(accountNodes_jack)
            nodeReward_jack = await MountainToken.calculateRewards(accountNodes_jack)    
            
            console.log(accountNodes_jack.toString())
            console.log(nodeMapping_jack)
            console.log(web3.utils.fromWei(nodeReward_jack))
        }

    

    })

    it ("prints the balances of all pools and the SC", async() => {
        await printPoolBalances();
        })    
    

    it("Jack claims rewards", async() => {

        balance = await MountainToken.balanceOf(jack)
        console.log(`Balance of jack before : ${web3.utils.fromWei(balance)}`); 

        await MountainToken.claimAllRewards.sendTransaction({
           from: jack,
           gas: 4000000,
         }); 

         balance = await MountainToken.balanceOf(jack)
         console.log(`Balance of jack after : ${web3.utils.fromWei(balance)}`); 


   });  



    // it("Jack buys tokens on TraderJoe", async() => {

		
    //     balance = await MountainToken.balanceOf.call(jack);
    //     console.log(`Balance of jack before : ${web3.utils.fromWei(balance)}`); 
        
        
    //     var MNT_to_buy = web3.utils.toWei("1000");
    //     await buyMNT(jack, MNT_to_buy);
    
    //     balance = await MountainToken.balanceOf.call(jack);
    //     console.log(`Balance of jack after : ${web3.utils.fromWei(balance)}`); 
    
    //     });     

//    it("Jack sells his rewards on TraderJoe", async() => {

		
//     balance = await MountainToken.balanceOf.call(jack);
//     console.log(`Balance of jack before : ${web3.utils.fromWei(balance)}`); 
    
    
//     var MNT_to_sell = web3.utils.toWei("1000");
//     await sellMNT(jack, MNT_to_sell);

//     balance = await MountainToken.balanceOf.call(jack);
//     console.log(`Balance of jack after : ${web3.utils.fromWei(balance)}`); 

//     }); 
      

    it ("prints the balances of all pools and the SC", async() => {
        await printPoolBalances();
    }) 


    
  
   
    
});

