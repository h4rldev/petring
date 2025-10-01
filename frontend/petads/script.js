"use strict";

function throw_dice() {
  let random = Math.floor(Math.random() * (1000 - 1 + 1) + 1);

  if (random > 500) {
    return true;
  }

  return false;
}

async function getRandomAd() {
  const image_element = document.getElementById("image");
  const image_link_element = document.getElementById("image-link");
  const promo_link_element = document.getElementById("promo-link");
  let response;


  try {
    response = await fetch("/api/get/random-ad");

    if (!response.ok) {
      const response_json = await response.json();
      throw new Error(response_json.message, { cause: response_json });
    }

    const data = await response.json();

    document.title = data.username;
    image_element.src = data.image_url;
    image_element.alt = data.username;
    image_link_element.href = data.ad_url;

    if (window.location.port !== undefined) {
      promo_link_element.href = `${window.location.protocol}//${window.location.hostname}:${window.location.port}/petads`;
    } else {
      promo_link_element.href = `${window.location.protocol}//${window.location.hostname}/petads`;
    }

  } catch (error) {
    console.error('Error fetching ad:', error);

    image_element.src = throw_dice() ?
      `https://http.dog/${error.cause.status}.jpg` :
      `https://http.cat/${error.cause.status}`;
    image_element.alt = error.cause.message;
    document.title = error.cause.message;
  }
  setTimeout(getRandomAd, 30000);
}

getRandomAd();
