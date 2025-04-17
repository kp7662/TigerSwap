const CourseToken  = artifacts.require("CourseToken");
const Swap3Brute   = artifacts.require("Swap3Brute");
const Swap3Adj     = artifacts.require("Swap3Adj");

module.exports = async function (deployer) {
  // 1) Deploy the CourseToken
  await deployer.deploy(CourseToken);
  const token = await CourseToken.deployed();

  // 2) Deploy the original brute‑force swap contract
  await deployer.deploy(Swap3Brute, token.address);

  // 3) Deploy the adjacency‑pruned swap contract
  await deployer.deploy(Swap3Adj, token.address);
};
