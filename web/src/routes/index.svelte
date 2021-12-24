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
	<p><span>{mathURL}</span></p>
	<button on:click={handleCopy}>copy</button>
	{#await imgSrc}
		<p>loading...</p>
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
</style>
