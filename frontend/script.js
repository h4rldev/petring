const test_json = {"users": [{"username": "h4rl","url": "https://h4rl.dev"},{"username": "doloro","url": "https://doloro.co.uk/"}]}

// allows mouse listeners to all links so animations stop when someone hovers over a link
function meow() {
const wrapper = document.getElementById('spin-item-wrapper'); // Note the period (.)
const allDivs = document.querySelectorAll('.spin-item-inner'); // Selects the spinning divs

allDivs.forEach(item => {
  item.addEventListener('mouseenter', () => {
    console.log('meow');
    wrapper.getAnimations().forEach(y => {y.pause()})
    allDivs.forEach(div => {
    	div.getAnimations().forEach(y => {y.pause()})    
		});
  });
  item.addEventListener('mouseleave', () => {
    wrapper.getAnimations().forEach(y => {y.play()})
    allDivs.forEach(div => {
    	div.getAnimations().forEach(y => {y.play()})   
		});
  });
});
}

document.addEventListener("DOMContentLoaded", function() {
	main();
});

function genDemoLinks() {
	test_json.users.forEach(user => {
		makeLink(user.username, user.url)
	})
	calculateRotations()
	meow()
}

async function genApiLinks() {
	const response = await fetch("/api/get/users");
	// error handling ?.. whats that? (tbh if the backend isnt up the frontend wouldnt be served so like :P)
	request.json().then((data) => {
		data.users.forEach(user => {
			makeLink(user.username, user.url)
		})
	})
	calculateRotations()
	meow()
}


// creates new spin-item element to be added to spin-items-wrapper
function makeLink(label, url) {
	const newSpinItem = document.createElement("span");
	newSpinItem.className = "spin-item"
	const newSpinItemInner = document.createElement("div")
	newSpinItemInner.className = "spin-item-inner"
	const hyperLink = document.createElement("a")
	hyperLink.href = url
	hyperLink.innerText = label

	newSpinItemInner.appendChild(hyperLink)
	newSpinItem.appendChild(newSpinItemInner)

	const wrapper = document.getElementById('spin-item-wrapper'); // Note the period (.)

	wrapper.appendChild(newSpinItem)
}

// calculates and applys rotations for all spin-items
function calculateRotations() {	
	const allDivs = document.querySelectorAll('.spin-item-inner'); // Selects the spinning divs
const wrapper = document.getElementById('spin-item-wrapper'); // Note the period (.)
const length = allDivs.length;

	  // Remove the animation
  wrapper.style.animation = 'none';

allDivs.forEach((item, i) => {
  item.parentNode.style.setProperty('--amount-of-element', length);
  item.parentNode.style.setProperty('--nth-element', i + 1);
  item.firstElementChild.style.transform = `rotate(calc((360deg / ${length}) * ${i + 1} * -1))`;
	item.style.animation = 'none';
});
	meow()

  void wrapper.offsetWidth; // broswer reflow (its for animations)

  wrapper.style.animation = 'spin 40s linear infinite';
	allDivs.forEach(item => {
		item.style.animation = 'counter-spin 40s linear infinite'
	})
}

function main() {
	if (location.protocol == 'file:') {
		genDemoLinks()
	} else {
		genApiLinks()
	}
}
