// this is just for local testing.. if it detects that the protocol is "file:/" itll just use this instead of fetching from backend
const test_json = {
  users: [
    { username: "h4rl", url: "https://h4rl.dev" },
    { username: "doloro", url: "https://doloro.co.uk/" },
    { username: "doloro", url: "https://doloro.co.uk/" },
    { username: "doloro", url: "https://doloro.co.uk/" },
  ],
};

let api_url = "http://localhost:8081";

// allows mouse listeners to all links so animations stop when someone hovers over a link
function meow() {
  const wrapper = document.getElementById("spin-item-wrapper"); // Note the period (.)
  const allDivs = document.querySelectorAll(".spin-item-inner"); // Selects the spinning divs

  allDivs.forEach((item) => {
    item.addEventListener("mouseenter", () => {
      console.log("meow");
      wrapper.getAnimations().forEach((y) => {
        y.pause();
      });
      allDivs.forEach((div) => {
        div.getAnimations().forEach((y) => {
          y.pause();
        });
      });
    });
    item.addEventListener("mouseleave", () => {
      wrapper.getAnimations().forEach((y) => {
        y.play();
      });
      allDivs.forEach((div) => {
        div.getAnimations().forEach((y) => {
          y.play();
        });
      });
    });
  });
}

function genDemoLinks() {
  test_json.users.forEach((user) => {
    makeLink(user.username, user.url);
  });
  calculateRotations();
  meow();
}

async function getUptimes() {
  let api_uptime_element = document.getElementById("api-uptime");
  let api_system_uptime_element = document.getElementById("api-system-uptime");
  let web_uptime_element = document.getElementById("web-uptime");
  let web_system_uptime_element = document.getElementById("web-system-uptime");

  fetch(`${api_url}/get/uptime`)
    .then((response) => response.json())
    .then((data) => {
      let api_data = data;
      api_uptime_element.innerText = `API: ${api_data.app_uptime}`;
      api_system_uptime_element.innerText = `API System: ${api_data.system_uptime}`;
    })
    .catch((error) => {
      console.error(error);
    });

  fetch("/api/get/uptime")
    .then((response) => response.json())
    .then((data) => {
      let web_data = data;
      web_uptime_element.innerText = `Web: ${web_data.app_uptime}`;
      web_system_uptime_element.innerText = `Web System: ${web_data.system_uptime}`;
    })
    .catch((error) => {
      console.error(error);
    });
}

async function genApiLinks() {
  fetch(`${api_url}/get/users`)
    .then((response) => response.json())
    .then((data) => {
      let users = data;
      users.users.forEach((user) => {
        makeLink(user.username, user.url);
      });
      calculateRotations();
      meow();
    })
    .catch((error) => {
      console.error(error);
    });
}

// creates new spin-item element to be added to spin-items-wrapper
function makeLink(label, url) {
  const newSpinItem = document.createElement("span");
  newSpinItem.className = "spin-item";
  const newSpinItemInner = document.createElement("div");
  newSpinItemInner.className = "spin-item-inner";
  const hyperLink = document.createElement("a");
  hyperLink.href = url;
  hyperLink.innerText = label;
  hyperLink.target = "_blank";

  newSpinItemInner.appendChild(hyperLink);
  newSpinItem.appendChild(newSpinItemInner);

  const wrapper = document.getElementById("spin-item-wrapper"); // Note the period (.)

  wrapper.appendChild(newSpinItem);
}

// calculates and applys rotations for all spin-items
function calculateRotations() {
  const allDivs = document.querySelectorAll(".spin-item-inner"); // Selects the spinning divs
  const wrapper = document.getElementById("spin-item-wrapper"); // Note the period (.)
  const length = allDivs.length;

  allDivs.forEach((item, i) => {
    item.parentNode.style.setProperty("--amount-of-element", length);
    item.parentNode.style.setProperty("--nth-element", i + 1);
    item.firstElementChild.style.transform = `rotate(calc((360deg / ${length}) * ${i + 1} * -1))`;
    item.style.animation = "none";
  });
  meow();

  wrapper.style.animation = "spin 40s linear infinite";
  allDivs.forEach((item) => {
    item.style.animation = "counter-spin 40s linear infinite";
  });
  void wrapper.offsetWidth; // broswer reflow (its for animations)
}

function setPetAdsEmbedExample() {
  const embed_example_element = document.getElementById("petad-embed-example");
  let url = window.location.href;

  embed_example_element.innerText = `<iframe src="${url}petads" height="300" allowtransparency="true" frameborder="0"></iframe>`;
}

function copyButton() {
  const copy_button = document.getElementById("copy-button");
  const embed_example_element = document.getElementById("petad-embed-example");

  copy_button.addEventListener("click", async function () {
    await navigator.clipboard.writeText(embed_example_element.innerText);
    copy_button.innerText = "Copied!";
    await new Promise((resolve) => setTimeout(resolve, 2000));
    copy_button.innerText = "Copy";
  });
}

async function main() {
  document.querySelectorAll('a[href^="#"]').forEach((anchor) => {
    anchor.addEventListener("click", function (e) {
      e.preventDefault();

      document.querySelector(this.getAttribute("href")).scrollIntoView({
        behavior: "smooth",
      });
    });
  });

  if (location.protocol == "file:") {
    genDemoLinks();
  } else {
    const api_url_fetch = await fetch("/api/get/api-url");
    let response = await api_url_fetch.json();
    api_url = response.api_url;

    setPetAdsEmbedExample();
    genApiLinks();
    getUptimes();
  }

  copyButton();
}

document.addEventListener("DOMContentLoaded", function () {
  main();
});
