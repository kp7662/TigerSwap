const CourseToken = artifacts.require("CourseToken");
const Swap3       = artifacts.require("Swap3");

contract("TigerSwap System", (accounts) => {
  const [admin, alice, bob, carol, dave, eve, frank] = accounts;
  let token, swap;

  beforeEach(async () => {
    token = await CourseToken.new({ from: admin });
    swap  = await Swap3.new(token.address, { from: admin });

    // Approve Swap3 to move all future tokens
    for (const acct of [alice, bob, carol, dave, eve, frank]) {
      await token.setApprovalForAll(swap.address, true, { from: acct });
    }
  });

  it("should auto-increment and mint NFTs with metadata", async () => {
    await token.mintCourseToken(alice, "COS324", "101", "Mon 10:00", "https://cos324.edu", { from: admin });
    await token.mintCourseToken(bob,   "COS226", "201", "Tue 11:00", "https://cos226.edu", { from: admin });
    const tokensAlice = await token.tokensOfOwner(alice);
    assert.equal(tokensAlice.length, 1);
    const details = await token.courseDetails(tokensAlice[0]);
    assert.equal(details[0], "COS324");
  });

  it("should prevent minting by non-owner", async () => {
    try {
      await token.mintCourseToken(bob, "COS109", "001", "Fri 1:00", "https://cos109.edu", { from: bob });
      assert.fail("Should not allow minting by non-owner");
    } catch (err) {
      assert(err.message.includes("Ownable"));
    }
  });

  it("should burn token and delete metadata", async () => {
    await token.mintCourseToken(alice, "COS324", "101", "Mon 10:00", "https://cos324.edu", { from: admin });
    await token.burnCourseToken(1, { from: admin });
    try {
      await token.courseDetails(1);
      assert.fail("Metadata should be deleted");
    } catch (err) {
      assert(err.message.includes("Token does not exist"));
    }
  });

  it("should submit and cancel a swap order", async () => {
    await token.mintCourseToken(alice, "COS324", "101", "Mon 10:00", "url", { from: admin });
    await swap.submitOrder(1, "COS226", { from: alice });
    await swap.cancelOrder(1, { from: alice });
    const orders = await swap.getActiveOrdersWithMetadata({ from: admin });
    assert.equal(orders.length, 0);
  });

  it("should execute a 2-way swap", async () => {
    await token.mintCourseToken(alice, "COS324", "101", "Mon 10:00", "url", { from: admin });
    await token.mintCourseToken(bob,   "COS226", "201", "Tue 11:00", "url", { from: admin });
    await swap.submitOrder(1, "COS226", { from: alice });
    await swap.submitOrder(2, "COS324", { from: bob });
    await swap.executeTwoWaySwaps({ from: admin });
    assert.equal(await token.ownerOf(1), bob);
    assert.equal(await token.ownerOf(2), alice);
  });

  it("should not swap if timing conflicts exist", async () => {
    await token.mintCourseToken(alice, "COS324", "101", "Mon 10:00", "url", { from: admin }); //1
    await token.mintCourseToken(bob,   "COS226", "201", "Mon 10:00", "url", { from: admin }); //2
    await token.mintCourseToken(alice, "COS000", "002", "Mon 10:00", "url", { from: admin }); //3
    await swap.submitOrder(1, "COS226", { from: alice });
    await swap.submitOrder(2, "COS324", { from: bob });
    await swap.executeTwoWaySwaps({ from: admin });
    assert.equal(await token.ownerOf(1), alice, "Swap should not happen due to timing conflict");
  });

  it("should execute a 3-way swap", async () => {
    await token.mintCourseToken(alice, "COS101", "001", "Mon 10:00", "url", { from: admin }); //1
    await token.mintCourseToken(bob,   "COS202", "002", "Tue 11:00", "url", { from: admin }); //2
    await token.mintCourseToken(carol, "COS303", "003", "Wed 12:00", "url", { from: admin }); //3
    await swap.submitOrder(1, "COS202", { from: alice });
    await swap.submitOrder(2, "COS303", { from: bob });
    await swap.submitOrder(3, "COS101", { from: carol });
    await swap.executeThreeWaySwaps({ from: admin });
    assert.equal(await token.ownerOf(1), carol);
    assert.equal(await token.ownerOf(2), alice);
    assert.equal(await token.ownerOf(3), bob);
  });

  it("should emit fallback message if no 3-way match exists", async () => {
    await token.mintCourseToken(alice, "COS101", "001", "Mon", "url", { from: admin });
    await token.mintCourseToken(bob,   "COS202", "002", "Tue", "url", { from: admin });
    await token.mintCourseToken(carol, "COS303", "003", "Wed", "url", { from: admin });
    await swap.submitOrder(1, "COS999", { from: alice });
    await swap.submitOrder(2, "COS888", { from: bob });
    await swap.submitOrder(3, "COS777", { from: carol });
    const tx     = await swap.executeThreeWaySwaps({ from: admin });
    const events = tx.logs.map(log => log.event);
    assert.include(events, "NoThreeWaySwapFound");
  });

  it("should handle multiple disjoint 3-way cycles", async () => {
    // Cycle 1
    await token.mintCourseToken(alice, "C1", "001", "Mon 9", "url", { from: admin }); //1
    await token.mintCourseToken(bob,   "C2", "001", "Tue 9", "url", { from: admin }); //2
    await token.mintCourseToken(carol, "C3", "001", "Wed 9", "url", { from: admin }); //3
    // Cycle 2
    await token.mintCourseToken(dave,  "C4", "001", "Thu 9", "url", { from: admin }); //4
    await token.mintCourseToken(eve,   "C5", "001", "Fri 9", "url", { from: admin }); //5
    await token.mintCourseToken(frank, "C6", "001", "Sat 9", "url", { from: admin }); //6

    // Submit cycle orders
    await swap.submitOrder(1, "C2", { from: alice });
    await swap.submitOrder(2, "C3", { from: bob });
    await swap.submitOrder(3, "C1", { from: carol });
    await swap.submitOrder(4, "C5", { from: dave });
    await swap.submitOrder(5, "C6", { from: eve });
    await swap.submitOrder(6, "C4", { from: frank });

    await swap.executeThreeWaySwaps({ from: admin });

    // Check no active orders remain
    const remaining = await swap.getActiveOrdersWithMetadata({ from: admin });
    assert.equal(remaining.length, 0);
  });

  it("should fallback to multiple 2-way swaps", async () => {
    await token.mintCourseToken(alice, "D1", "001", "Mon", "url", { from: admin }); //1
    await token.mintCourseToken(bob,   "D2", "001", "Tue", "url", { from: admin }); //2
    await token.mintCourseToken(carol, "D3", "001", "Wed", "url", { from: admin }); //3
    await token.mintCourseToken(dave,  "D4", "001", "Thu", "url", { from: admin }); //4

    await swap.submitOrder(1, "D2", { from: alice });
    await swap.submitOrder(2, "D1", { from: bob });
    await swap.submitOrder(3, "D4", { from: carol });
    await swap.submitOrder(4, "D3", { from: dave });

    const tx3 = await swap.executeThreeWaySwaps({ from: admin });
    assert.include(tx3.logs.map(l => l.event), "NoThreeWaySwapFound");

    await swap.executeTwoWaySwaps({ from: admin });

    const remaining = await swap.getActiveOrdersWithMetadata({ from: admin });
    assert.equal(remaining.length, 0);
  });

  it("should allow a student to submit multiple orders and execute them", async () => {
    await token.mintCourseToken(alice, "X1", "001", "Mon", "url", { from: admin }); //1
    await token.mintCourseToken(alice, "X2", "002", "Tue", "url", { from: admin }); //2
    await token.mintCourseToken(bob,   "X3", "003", "Wed", "url", { from: admin }); //3
    await token.mintCourseToken(carol, "X4", "004", "Thu", "url", { from: admin }); //4

    await swap.submitOrder(1, "X3", { from: alice });
    await swap.submitOrder(2, "X4", { from: alice });
    await swap.submitOrder(3, "X1", { from: bob });
    await swap.submitOrder(4, "X2", { from: carol });

    await swap.executeThreeWaySwaps({ from: admin });
    await swap.executeTwoWaySwaps({ from: admin });

    const remaining = await swap.getActiveOrdersWithMetadata({ from: admin });
    assert.equal(remaining.length, 0);
  });

  it("admin can cancel all orders at once", async () => {
    await token.mintCourseToken(alice, "Z1", "001", "Mon", "url", { from: admin });
    await token.mintCourseToken(bob,   "Z2", "002", "Tue", "url", { from: admin });

    await swap.submitOrder(1, "Z2", { from: alice });
    await swap.submitOrder(2, "Z1", { from: bob });

    let activeBefore = await swap.getActiveOrdersWithMetadata({ from: admin });
    assert.equal(activeBefore.length, 2);

    await swap.cancelAllOrders({ from: admin });
    let activeAfter = await swap.getActiveOrdersWithMetadata({ from: admin });
    assert.equal(activeAfter.length, 0);
  });

  it("should handle empty orderbook gracefully", async () => {
    const tx3 = await swap.executeThreeWaySwaps({ from: admin });
    assert.include(tx3.logs.map(l => l.event), "NoThreeWaySwapFound");

    const tx2 = await swap.executeTwoWaySwaps({ from: admin });
    assert.include(tx2.logs.map(l => l.event), "TwoWaySwapCompleted");

    const remaining = await swap.getActiveOrdersWithMetadata({ from: admin });
    assert.equal(remaining.length, 0);
  });
});