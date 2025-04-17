// scripts/benchmarkThreeWayTime.js
module.exports = async function(callback) {
    try {
      const CourseToken = artifacts.require("CourseToken");
      const Swap3Brute  = artifacts.require("Swap3Brute");
      const Swap3Adj    = artifacts.require("Swap3Adj");
  
      const accounts     = await web3.eth.getAccounts();
      const admin        = accounts[0];
      const participants = accounts.slice(1, 10); // up to 9 swap users
      const courseIds    = ["C1","C2","C3","C4","C5","C6","C7","C8","C9","C10"];
  
      // Ns to benchmark
      const Ns = [2, 4, 6, 8, 10, 12, 14, 16, 18, 20];
  
      console.log("Benchmarking 3-way swap execution time for N =", Ns.join(", "));
      console.log("--------------------------------------------------");
      console.log(" N  |  timeBrute(ms)  |  timeAdj(ms)");
      console.log("----+-----------------+---------------");
  
      for (const N of Ns) {
        // BRUTE FORCE PATH
        const tokenB = await CourseToken.new({ from: admin });
        const brute  = await Swap3Brute.new(tokenB.address, { from: admin });
  
        // approvals
        for (const p of participants) {
          await tokenB.setApprovalForAll(brute.address, true, { from: p });
        }
        // mint & submit orders
        for (let i = 0; i < N; i++) {
          const owner     = participants[i % participants.length];
          const offered   = courseIds[i % courseIds.length];
          const requested = courseIds[(i + 1) % courseIds.length];
          const timing    = offered;
  
          await tokenB.mintCourseToken(owner, offered, String(i + 1), timing, "url", { from: admin });
          await brute.submitOrder(i + 1, requested, { from: owner });
        }
        // measure brute execution time
        const startB = Date.now();
        await brute.executeThreeWaySwaps({ from: admin });
        const endB = Date.now();
        const timeBrute = endB - startB;
  
        // ADJACENCY PRUNED PATH
        const tokenA = await CourseToken.new({ from: admin });
        const adj    = await Swap3Adj.new(tokenA.address, { from: admin });
  
        // approvals
        for (const p of participants) {
          await tokenA.setApprovalForAll(adj.address, true, { from: p });
        }
        // mint & submit orders
        for (let i = 0; i < N; i++) {
          const owner     = participants[i % participants.length];
          const offered   = courseIds[i % courseIds.length];
          const requested = courseIds[(i + 1) % courseIds.length];
          const timing    = offered;
  
          await tokenA.mintCourseToken(owner, offered, String(i + 1), timing, "url", { from: admin });
          await adj.submitOrder(i + 1, requested, { from: owner });
        }
        // measure adjacency execution time
        const startA = Date.now();
        await adj.executeThreeWaySwaps({ from: admin });
        const endA = Date.now();
        const timeAdj = endA - startA;
  
        console.log(
          `${String(N).padStart(2)}  |  ${String(timeBrute).padStart(13)}  |  ${String(timeAdj).padStart(11)}`
        );
      }
  
      console.log("--------------------------------------------------");
      callback();
    } catch (err) {
      callback(err);
    }
  };