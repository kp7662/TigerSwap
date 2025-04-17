// scripts/benchmarkThreeWay.js
module.exports = async function(callback) {
    try {
      const CourseToken = artifacts.require("CourseToken");
      const Swap3Brute  = artifacts.require("Swap3Brute");
      const Swap3Adj    = artifacts.require("Swap3Adj");
  
      // Use Truffle's global web3 instance
      const accounts     = await web3.eth.getAccounts();
      const admin        = accounts[0];
      const participants = accounts.slice(1, 10); // up to 9 swap users
      const courseIds    = ["C1","C2","C3","C4","C5","C6","C7","C8","C9","C10"];
  
      // Ns to test – start small, then you can expand
      const Ns = [2, 4, 6, 8, 10, 12, 14, 16, 18, 20];
  
      console.log("Benchmarking 3-way swaps for N =", Ns.join(", "));
      console.log("--------------------------------------------------");
      console.log(" N  |  gasBrute  |  gasAdj");
      console.log("----+------------+---------");
  
      for (const N of Ns) {
        // 1) deploy fresh contracts
        const token = await CourseToken.new({ from: admin });
        const brute = await Swap3Brute.new(token.address, { from: admin });
        const adj   = await Swap3Adj.new(  token.address, { from: admin });
  
        // 2) approvals
        for (const p of participants) {
          await token.setApprovalForAll(brute.address, true, { from: p });
          await token.setApprovalForAll(adj.address,   true, { from: p });
        }
  
        // 3) mint N tokens & submit N orders
        for (let i = 0; i < N; i++) {
          const owner    = participants[i % participants.length];
          const offered  = courseIds[i % courseIds.length];
          const requested= courseIds[(i + 1) % courseIds.length];
          const timing   = offered; // unique timing = courseId
  
          // mint tokenId = i+1
          await token.mintCourseToken(
            owner,
            offered,
            String(i + 1),
            timing,
            "https://example.com/" + offered,
            { from: admin }
          );
          // submit orders
          await brute.submitOrder(i + 1, requested, { from: owner });
          await adj.submitOrder(  i + 1, requested, { from: owner });
        }
  
        // 4) estimate gas
        const gasBrute = await brute.executeThreeWaySwaps.estimateGas({ from: admin });
        const gasAdj   = await adj.executeThreeWaySwaps.estimateGas({ from: admin });
  
        console.log(
          `${String(N).padStart(2)}  |  ${String(gasBrute).padStart(8)}  |  ${String(gasAdj).padStart(7)}`
        );
      }
  
      console.log("--------------------------------------------------");
      callback();
    } catch (err) {
      callback(err);
    }
  };