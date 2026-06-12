window.addEventListener('DOMContentLoaded', () => {
    getVisitorCount();
});

const apiEndpoint = "https://jb6xr0cby2.execute-api.us-east-1.amazonaws.com/counter";

async function getVisitorCount() {
    try {
        let response = await fetch(apiEndpoint);
        let data = await response.json();
        document.getElementById("counter").innerText = `Visitor Count: ${data.count}`;
    } catch (error) {
        console.error("Error fetching visitor metrics from API Gateway:", error);
        document.getElementById("counter").innerText = "Visitor Count: Unavailable";
    }
}