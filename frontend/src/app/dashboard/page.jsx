"use client";
import Image from "next/image";
import Link from "next/link";
import { useState, useEffect } from "react";
import Navbar from "../../../components/Navbar";
import '@mysten/dapp-kit/dist/index.css';
import { getFullnodeUrl, SuiClient } from '@mysten/sui.js/client';
import NftdataContainer from "../../../components/NftDataContainer";
import {useWallet} from '@suiet/wallet-kit';

const Dashboard = () => {

  const [loading, setLoading] = useState(false);
    const [nftdata, setnftdata] = useState(null);
    const wallet = useWallet();


    useEffect(() => {
        const getnft = async() => {
          setLoading(true);
          const suiClient = new SuiClient({ url: getFullnodeUrl("devnet") });
          const objects = await suiClient.getOwnedObjects({ owner: wallet?.address});

          console.log("objet", objects)
          const widgets = [];
          
          // iterate through all objects owned by address
          for (let i = 0; i < objects.data.length; i++) {
            const currentObjectId = objects.data[i].data.objectId;
          
            // get object information
            const objectInfo = await suiClient.getObject({
              id: currentObjectId,
              options: { showContent: true },
            });
    
            console.log("objectInfo", objectInfo);
          
            const packageId = '0x70f67e5d6cb48ffdffaa866f9e06686ccfa2c566441bda18f33233253186b819';
          
            if (objectInfo?.data?.content?.type == `${packageId}::pet::PetPassport`) {
              // const widgetObjectId = objectInfo.data.content.fields.id.id;
              const widgetObjectId = objectInfo.data;
              console.log("widget spotted:", widgetObjectId);
              widgets.push(widgetObjectId);
            }
          }
          
          console.log("widgets:", widgets);
          setnftdata(widgets);
          setLoading(false);
        }
    
        getnft();
      }, [wallet.address])

  return (
    <main>
<div className="z-0" 
style={{backgroundImage: 'url(https://wallpapers.com/images/hd/brown-background-u240zdqxs8ns0qnx.jpg)', backgroundSize:'cover', backgroundRepeat:'no repeat', backgroundPosition:'center'}}
 >
      <div className="max-w-7xl mx-auto">
        <div className="justify-between flex">
          <Link href="/">
       <img src="/petpasslogo.png" className="w-24 h-34 pt-10"/>
       </Link>
       <div className="my-10 my-auto">
       <Navbar />
       </div>
       </div>
          <div className='font-bold text-5xl mt-20 mb-10' style={{color:'#640D6B'}}>Your Registered Pets</div>

          <NftdataContainer metaDataArray={nftdata} MyReviews={false} />
    </div>

    {loading && (
        <div
          style={{ backgroundColor: "#222944E5" }}
          className="flex overflow-y-auto overflow-x-hidden fixed inset-0 z-50 justify-center items-center w-full max-h-full"
          id="popupmodal"
        >
          <div className="relative p-4 lg:w-1/5 w-full max-w-2xl max-h-full">
            <div className="relative rounded-lg shadow">
              <div className="flex justify-center gap-4">
                <img
                  className="w-100 h-90"
                  src="/loader.gif"
                  alt="Loading icon"
                />
              </div>
            </div>
          </div>
        </div>
      )}

    </div>
    </main>
  )
}

export default Dashboard