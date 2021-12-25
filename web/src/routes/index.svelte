<script context="module" lang="ts">
	export const prerender = true;
</script>

<script lang="ts">
	type ImgState =
		| {
				state: 'success';
				url: string;
		  }
		| {
				state: 'error';
				txt: string;
		  };

	function base64Encode(src: string) {
		const binStr = unescape(encodeURIComponent(src));
		return btoa(binStr);
	}
	function makeMathUrl(src: string) {
		return `https://satymathbot.net/m/${base64Encode(src)}.png`;
	}
	let math = 'e^{i\\pi} + 1 = 0';
	let mathURL = makeMathUrl(math);
	let imgSrc: Promise<ImgState> = (async () => {
		return { state: 'success', url: mathURL };
	})();
	function handleShow() {
		const url = makeMathUrl(math);
		mathURL = url;
		async function request(): Promise<ImgState> {
			const res = await fetch(url);
			if (res.ok) {
				const blob = await res.blob();
				return {
					state: 'success',
					url: URL.createObjectURL(blob)
				};
			} else {
				const txt = await res.text();
				return {
					state: 'error',
					txt
				};
			}
		}
		imgSrc = request();
	}
	function handleCopy() {
		navigator.clipboard.writeText(mathURL);
	}
</script>

<svelte:head>
	<title>Home</title>
</svelte:head>

<section>
	<h1>SATyMathBot</h1>
	<input type="text" bind:value={math} />
	<button on:click={handleShow}>show</button>
	<pre>{mathURL}</pre>
	<button on:click={handleCopy}>copy</button>
	{#await imgSrc}
		<div class="loader">loading...</div>
	{:then src}
		{#if src.state === 'success'}
			<img src={src.url} alt={mathURL} />
		{:else}
			<p>{src.txt}</p>
		{/if}
	{/await}
</section>

<style>
	section {
		display: flex;
		flex-direction: column;
		align-items: center;
	}
	.loader,
	.loader:after {
		border-radius: 50%;
		width: 10em;
		height: 10em;
	}
	.loader {
		margin: 60px auto;
		font-size: 10px;
		position: relative;
		text-indent: -9999em;
		border-top: 1.1em solid rgba(255, 255, 255, 0.2);
		border-right: 1.1em solid rgba(255, 255, 255, 0.2);
		border-bottom: 1.1em solid rgba(255, 255, 255, 0.2);
		border-left: 1.1em solid #000000;
		-webkit-transform: translateZ(0);
		-ms-transform: translateZ(0);
		transform: translateZ(0);
		-webkit-animation: load8 0.7s infinite linear;
		animation: load8 0.7s infinite linear;
	}
	@-webkit-keyframes load8 {
		0% {
			-webkit-transform: rotate(0deg);
			transform: rotate(0deg);
		}
		100% {
			-webkit-transform: rotate(360deg);
			transform: rotate(360deg);
		}
	}
	@keyframes load8 {
		0% {
			-webkit-transform: rotate(0deg);
			transform: rotate(0deg);
		}
		100% {
			-webkit-transform: rotate(360deg);
			transform: rotate(360deg);
		}
	}
</style>
