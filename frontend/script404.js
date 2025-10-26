let api_url = "http://localhost:8081";

async function getUptimes() {
	const api_uptime_element = document.getElementById("api-uptime");
	const api_system_uptime_element =
		document.getElementById("api-system-uptime");
	const web_uptime_element = document.getElementById("web-uptime");
	const web_system_uptime_element =
		document.getElementById("web-system-uptime");

	fetch(`${api_url}/get/uptime`)
		.then((response) => response.json())
		.then((data) => {
			const api_data = data;
			api_uptime_element.innerText = `API: ${api_data.app_uptime}`;
			api_system_uptime_element.innerText = `API System: ${api_data.system_uptime}`;
		})
		.catch((error) => {
			console.error(error);
		});

	fetch("/api/get/uptime")
		.then((response) => response.json())
		.then((data) => {
			const web_data = data;
			web_uptime_element.innerText = `Web: ${web_data.app_uptime}`;
			web_system_uptime_element.innerText = `Web System: ${web_data.system_uptime}`;
		})
		.catch((error) => {
			console.error(error);
		});
}

async function main() {
	if (location.protocol !== "file:") {
		const api_url_fetch = await fetch("/api/get/api-url");
		const response = await api_url_fetch.json();
		api_url = response.api_url;
		await getUptimes();
	}
}

document.addEventListener("DOMContentLoaded", () => {
	main();
});
