"use strict";

function flipCoin() {
  let random = Math.floor(Math.random() * (1000 - 1 + 1) + 1);

  if (random > 500) {
    return true;
  }

  return false;
}

let api_url;

async function getRandomAd() {
  const image_element = document.getElementById("image");
  const image_link_element = document.getElementById("image-link");
  const promo_link_element = document.getElementById("promo-link");

  fetch(`${api_url}/get/random-ad`)
    .then((response) => {
      if (!response.ok) {
        return Promise.reject(response);
      }
      return response.json();
    })
    .then((data) => {
      let ad_data = data;

      document.title = data.username;
      image_element.src = data.image_url;
      image_element.alt = data.username;
      image_link_element.href = data.ad_url;
      promo_link_element.innerText = `from ${data.username} (click here for more info about PetAds)`;
    })
    .catch(async (error) => {
      if (error instanceof Response) {
        let json = await error.json();
        let message = `${error.status}: ${json.message}`;
        image_element.src = flipCoin()
          ? `https://http.dog/${error.status}.jpg`
          : `https://http.cat/${error.status}`;
        image_element.alt = message;
        document.title = message;
      } else {
        console.error("Network error:", error);
      }
    });

  // if (!response.ok) {
  //  const response_json = await response.json();
  //  throw new Error(response_json.message, { cause: response_json });
  //}
  // console.error("Error fetching ad:", error);

  // }
  setTimeout(getRandomAd, 30000);
}

async function main() {
  const api_url_fetch = await fetch("/api/get/api-url");
  const response_json = await api_url_fetch.json();
  const promo_link_element = document.getElementById("promo-link");
  api_url = response_json.api_url;

  if (window.location.port !== undefined) {
    promo_link_element.href = `${window.location.protocol}//${window.location.hostname}:${window.location.port}/`;
  } else {
    promo_link_element.href = `${window.location.protocol}//${window.location.hostname}/`;
  }

  getRandomAd();
}

document.addEventListener("DOMContentLoaded", function () {
  main();
});
