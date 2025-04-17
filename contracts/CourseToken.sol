// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./Base64.sol";

contract CourseToken is ERC721, Ownable {
    struct CourseMetadata {
        string courseID;
        string preceptID;
        string timing;
        string coursePageURL;
    }

    mapping(uint256 => CourseMetadata) public tokenMeta;
    uint256 private nextTokenId = 1;

    constructor() ERC721("CourseToken", "CTKN") {}

    function mintCourseToken(
        address to,
        string memory _courseID,
        string memory _preceptID,
        string memory _timing,
        string memory _coursePageURL
    ) public onlyOwner {
        uint256 tokenId = nextTokenId;
        _mint(to, tokenId);
        tokenMeta[tokenId] = CourseMetadata(_courseID, _preceptID, _timing, _coursePageURL);
        nextTokenId++;
    }

    function burnCourseToken(uint256 tokenId) public onlyOwner {
        require(_exists(tokenId), "Token does not exist");
        _burn(tokenId);
        delete tokenMeta[tokenId];
    }

    function courseDetails(uint256 tokenId)
        public
        view
        returns (string memory, string memory, string memory, string memory)
    {
        require(_exists(tokenId), "Token does not exist");
        CourseMetadata memory meta = tokenMeta[tokenId];
        return (meta.courseID, meta.preceptID, meta.timing, meta.coursePageURL);
    }

    // Reimplemented without ERC721Enumerable
    function tokensOfOwner(address owner) public view returns (uint256[] memory) {
        uint256 count = balanceOf(owner);
        uint256[] memory tokenIds = new uint256[](count);
        uint256 found = 0;
        for (uint256 i = 1; found < count && i < nextTokenId; i++) {
            if (_exists(i) && ownerOf(i) == owner) {
                tokenIds[found] = i;
                found++;
            }
        }
        return tokenIds;
    }

    function tokensAndMetadataOfOwner(address owner) public view returns (CourseMetadata[] memory) {
        uint256 count = balanceOf(owner);
        CourseMetadata[] memory metadataList = new CourseMetadata[](count);
        uint256 found = 0;
        for (uint256 i = 1; found < count && i < nextTokenId; i++) {
            if (_exists(i) && ownerOf(i) == owner) {
                metadataList[found] = tokenMeta[i];
                found++;
            }
        }
        return metadataList;
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");
        CourseMetadata memory meta = tokenMeta[tokenId];

        string memory name = string(abi.encodePacked(meta.courseID, " Precept ", meta.preceptID));
        string memory description = string(
            abi.encodePacked(
                "Course: ", meta.courseID,
                ", Precept: ", meta.preceptID,
                ", Timing: ", meta.timing,
                ". More info: ", meta.coursePageURL
            )
        );

        string memory svgImage = string(
            abi.encodePacked(
                "<svg xmlns='http://www.w3.org/2000/svg' width='350' height='350' style='background-color:orange;'>",
                "<text x='50%' y='50%' fill='white' dominant-baseline='middle' text-anchor='middle' font-size='16'>",
                meta.courseID, " - ", meta.preceptID, " (", meta.timing, ")",
                "</text></svg>"
            )
        );

        string memory imageBase64 = Base64.encode(bytes(svgImage));
        string memory imageURI = string(abi.encodePacked("data:image/svg+xml;base64,", imageBase64));

        string memory json = string(
            abi.encodePacked(
                '{"name":"', name,
                '","description":"', description,
                '","image":"', imageURI,
                '","attributes":[{"trait_type":"Course ID","value":"', meta.courseID,
                '"},{"trait_type":"Precept ID","value":"', meta.preceptID,
                '"},{"trait_type":"Timing","value":"', meta.timing,
                '"}]}'
            )
        );

        string memory jsonBase64 = Base64.encode(bytes(json));
        return string(abi.encodePacked("data:application/json;base64,", jsonBase64));
    }
}
