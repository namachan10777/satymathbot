<script context="module" lang="ts">
	export const prerender = true;
</script>

<script lang="ts">
	function base64Encode(src: string) {
		const binStr = unescape(encodeURIComponent(src));
		return btoa(binStr);
	}
	function makeMathUrl(src: string) {
		return `https://satymathbot.net/m/${base64Encode(src)}.png`;
	}
	function handleShow() {
		const url = makeMathUrl(math);
		fetch(url, {  }).then((res) => {
			if (res.url === url) {
				res.blob().then((blob) => {
					console.log(blob);
					imgSrc = URL.createObjectURL(blob);
				}).catch(err => {
					console.log(err);
				});
			}
		});
	}
	let math = '1+1';
	let imgSrc = makeMathUrl(math);
</script>

<svelte:head>
	<title>Home</title>
</svelte:head>

<section>
	<h1>SATyMathBot</h1>
	<input type="text" bind:value={math} />
	<button on:click={handleShow}>show</button>
	<img src={imgSrc} alt={math} />
</section>

<style>
	section {
		display: flex;
		flex-direction: column;
		align-items: center;
	}
</style>
