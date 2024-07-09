import React, {useEffect, useState} from "react";
import axios from "axios";
import Link from "next/link";

const truncateDescription = (
  description,
  maxLength
) => {
  const words = description.split(" ");
  const truncatedWords = words.slice(0, maxLength);
  return truncatedWords.join(" ") + (words.length > maxLength ? "..." : "");
};

const NftdataCard = ({
  metaData,
}) => {

  const [imageSrc, setImageSrc] = useState(null);
  const [isDropdownOpen, setIsDropdownOpen] = useState(false);

  useEffect(() => {
    const fetchData = async () => {
      try {
        const urlhash = metaData.content.fields.url.slice(7)
        console.log("urlhash", urlhash);
        const data = await fetch(`https://nftstorage.link/ipfs/${urlhash}`); // Replace with your IPFS hash
        const ipfsdata = await data.json();

        const ipfsCid = ipfsdata.petimg.replace("ipfs://", "");
        setImageSrc(ipfsCid);
        console.log("ipfs data", ipfsdata)
      } catch (err) {
        console.log('Failed to fetch data from IPFS');
      }
    };

    fetchData();
  }, [metaData]);

  if (!metaData) {
    return (
      <div className="flex flex-col items-center justify-center w-full max-w-sm mx-auto">
        <div
          className="w-full h-72 p-5 bg-center bg-cover"
          style={{ display: "flex", alignItems: "center" }}
        >
          <div className="animate-spin rounded-full h-32 w-32 mx-auto border-t-2 border-b-2 border-green-200"></div>
        </div>
      </div>
    );
  }

  return (
    <>
    { isDropdownOpen ? (
  <div className="z-50 flex items-center justify-center bg-opacity-50 w-full rounded-2xl"
  style={{
    boxShadow: "inset -10px -10px 60px 0 rgba(255, 255, 255, 0.4)",
    backgroundColor: "rgba(255, 255, 255, 0.4)"
  }}
  >
    <div className="rounded-lg shadow-lg w-full text-black h-full justify-center items-center mx-auto flex flex-col gap-10 text-center" style={{paddingTop:80, paddingBottom:80}}>
        <div className="">
        <Link href={`/transfer?objId=${metaData.objectId}&peturl=${encodeURIComponent(metaData.content.fields.url.slice(7))}`} className="px-10 py-3 cursor-pointer rounded-lg bg-white" style={{border: '1px solid brown', color:'brown'}}>Transfer Pet</Link>
        </div>
        {/* <div style={{marginTop: 40}}>
        <Link href={`/vaccinationRec?objId=${metaData.objectId}`} className="px-4 py-3 cursor-pointer rounded-lg bg-white mt-4" style={{border: '1px solid brown', color:'brown'}}>Add vaccination and clinical records</Link>
        </div> */}
        {/* <div style={{marginTop: 24}}>
        <Link href={`/adoptionForm?peturl=${encodeURIComponent(metaData.content.fields.url.slice(7))}`} className="px-4 py-2 cursor-pointer rounded-lg bg-white" style={{border: '1px solid brown', color:'brown'}}>Up for adoption</Link>
        </div> */}
      <button onClick={()=>{setIsDropdownOpen(!isDropdownOpen)}} className="mt-4 px-10 py-3 rounded-lg text-white" style={{backgroundColor:'red', marginTop:30}}>
        Close
      </button>
    </div>
  </div>
    ):(

    <div className="w-full rounded-2xl" 
    style={{
      boxShadow: "inset -10px -10px 60px 0 rgba(255, 255, 255, 0.4)",
      backgroundColor: "rgba(255, 255, 255, 0.4)"
    }}>
      <div className="w-full h-full rounded-lg p-4">
        <div>
          <div className="justify-between flex">
          <button onClick={()=>{setIsDropdownOpen(!isDropdownOpen)}} className="rounded-full">
            <img
              src="https://cdn-icons-png.flaticon.com/256/10949/10949950.png"
              style={{ width: 30, marginTop: -20 }}
            />
          </button>

        <Link href={`https://suiscan.xyz/devnet/object/${metaData.objectId}`} target="_blank">
        <div className="flex gap-4 text-black">
        <div className="text-sm py-4 font-bold">View on explorer</div>
              <img src="https://cdn.dribbble.com/users/1665993/screenshots/3881539/dogsicon.gif" alt="" className="rounded-full" width="80"/>
              </div>
              </Link>
              </div>
          <div className="flex flex-row gap-4">
            <div className="w-1/2">
              {imageSrc ? (<img
                      alt="alt"
                      src={`${
                        "https://nftstorage.link/ipfs"
                      }/${imageSrc}`}
                      className="rounded-full w-40 h-40"
                    />):(
                      <img
                      alt="alt"
                      src={`https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcRgv-OTIZFq4vgV-pN5dJEKzox2aDB1aiaYGQ&s`}
                      className="rounded-full w-40 h-40"
                    />
                    )}
                    <div className="text-center mt-4 text-sm font-bold" style={{color:'brown'}}>
                    {metaData.content.fields.pet_info[0]}, {metaData.content.fields.pet_info[1]}, Age: {metaData.content.fields.pet_info[4]}
                  </div>
            </div>
            <div className="w-full">

              <div className="rounded-xl">
                <div className="text-md text-black text-start flex mt-2 mb-2 justify-between">
                  <div>
                    <span className="font-bold" style={{color:'black'}}>Breed: &nbsp;</span> {metaData.content.fields.pet_info[2]}
                    </div>
                    <div>
                    <span className="font-bold" style={{color:'black'}}>Gender: &nbsp;</span> {metaData.content.fields.pet_info[3]}
                    </div>
                </div>
              </div>

                <div className="text-black text-start mt-2">
                <span className="font-bold text-md" style={{color:'black'}}>Color/Markings: &nbsp;</span> 
                <span className="text-sm">{metaData.content.fields.pet_info[5]}</span>
                </div>

                <div className="text-black text-start mt-2 flex justify-between">
                  <div>
                <span className="font-bold text-md" style={{color:'black'}}>Owner: &nbsp;</span> 
                <span className="text-sm">{metaData.content.fields.owner_info[0]}</span>
                </div>
                <div>
                <span className="font-bold text-md" style={{color:'black'}}>Contact: &nbsp;</span> 
                <span className="text-sm">{metaData.content.fields.owner_info[1]}</span>
                </div>
                </div>

                <div className="text-black text-start mt-2 flex justify-between gap-4">
                  <div>
                <div className="font-bold text-md" style={{color:'black'}}>Microchip number: &nbsp;</div> 
                <div className="text-sm">{metaData.content.fields.microchip_info[0]}</div>
                </div>
                <div>
                <div className="font-bold text-md" style={{color:'black'}}>Microchip date: &nbsp;</div> 
                <div className="text-sm">{metaData.content.fields.microchip_info[1]}</div>
                </div>
                </div>

                <div className="text-black text-start mt-2">
                <span className="font-bold text-md" style={{color:'black'}}>Microchip location: &nbsp;</span> 
                <span className="text-sm">{metaData.content.fields.microchip_info[2]}</span>
                </div>

                <div className="text-black text-start mt-2">
                <span className="font-bold text-md" style={{color:'black'}}>Vaccination Record: &nbsp;</span> 
                <span className="text-sm">{metaData.content.fields.vaccination_rec.length > 0 ? metaData.content.fields.vaccination_rec[0]: "Not Entered"}</span>
                </div>

            </div>
          </div>
        </div>
      </div>
    </div>
    )}
    </>
  );
};

export default NftdataCard;
