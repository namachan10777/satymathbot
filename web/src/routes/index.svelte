<script context="module" lang="ts">
	export const prerender = true;
</script>

<script lang="ts">
	// type definitions
	type ImgState =
		| {
				state: 'success';
				url: string;
		  }
		| {
				state: 'error';
				txt: string;
		  };
	type SveltEvent<T> = Event & { currentTarget: T };

	// helper functions
	function base64Encode(src: string) {
		const binStr = unescape(encodeURIComponent(src));
		return btoa(binStr);
	}
	function createMathURL(math: string, format: string, color: string): string {
		return `https://satymathbot.net/m/${base64Encode(math)}.${format}?color=${color}`;
	}

	// state
	let math = 'e^{i\\pi} + 1 = 0';
	let format = 'png';
	let color = '000';
	let mathURL = createMathURL(math, format, color);
	let imgSrc: Promise<ImgState> = (async () => {
		return { state: 'success', url: mathURL };
	})();

	// handlers
	let fetchAbortController: null | AbortController = null;
	let fetchGraceID: null | number = null;

	async function request(): Promise<ImgState> {
		let url = mathURL;
		if (fetchAbortController) {
			fetchAbortController.abort();
		}
		fetchAbortController = new AbortController();
		const res = await fetch(mathURL, {
			signal: fetchAbortController.signal
		});
		if (res.ok && res.url === url) {
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

	function fetchImageSpeculative() {
		if (fetchGraceID) {
			clearTimeout(fetchGraceID);
		}
		fetchGraceID = window.setTimeout(() => {
			imgSrc = request();
		}, 300);
	}
	function handleCopy() {
		navigator.clipboard.writeText(mathURL);
	}
	function handleMathUpdate(e: SveltEvent<HTMLInputElement>) {
		mathURL = createMathURL(e.currentTarget.value, format, color);
		fetchImageSpeculative();
	}
	function handleFormatUpdate(e: SveltEvent<HTMLInputElement>) {
		mathURL = createMathURL(math, e.currentTarget.value, color);
		fetchImageSpeculative();
	}
	function handleColorUpdate(e: SveltEvent<HTMLInputElement>) {
		mathURL = createMathURL(math, format, e.currentTarget.value.slice(1));
		fetchImageSpeculative();
	}
</script>

<svelte:head>
	<title>SATyMathBot</title>
</svelte:head>

<section class="bg-gray-200 min-h-full flex flex-col justify-center">
	<div
		class="shadow-md rounded py-2 card-width-default mx-2 px-2 bg-white m-1 border flex flex-col items-center "
	>
		<h1 class="text-xl">SATyMathBot</h1>
		<p>
			A formula rendering server driven by <a
				class="underline text-indigo-700 hover:text-indigo-500"
				href="https://github.com/gfngfn/SATySFi">SATySFi</a
			>.
		</p>
		<div class="w-full border-b border-gray-500 my-2" />
		<input
			type="text"
			class="w-full border-indigo-700 leading-tight shadow appearance-none border rounded px-2 py-1 focus:outline-none focus:shadow-outline"
			on:input={handleMathUpdate}
			bind:value={math}
		/>
		<label>
			Text color
			<input type="color" on:change={handleColorUpdate} />
		</label>
		<form class="flex flex-col">
			<label
				><input
					bind:group={format}
					on:change={handleFormatUpdate}
					name="format"
					value="png"
					type="radio"
					checked
				/> PNG</label
			>
			<label
				><input
					bind:group={format}
					on:change={handleFormatUpdate}
					name="format"
					value="jpeg"
					type="radio"
				/> JPEG</label
			>
		</form>
		<pre
			class="p-1 leading-tight w-full border border-indigo-200 rounded overflow-scroll font-mono">{mathURL}</pre>
		<button
			class="rounded my-1 border-2 border-indigo-700 text-indigo-700 px-1 hover:text-white hover:bg-indigo-700"
			on:click={handleCopy}>copy</button
		>
		<div class="img-box flex flex-col items-center justify-center w-full">
			{#await imgSrc}
				<div class="loader">loading...</div>
			{:then src}
				{#if src.state === 'success'}
					<img class="my-2 border border-indigo-400" src={src.url} alt={mathURL} />
				{:else}
					<pre
						class="overflow-scroll bg-gray-100 p-1 rounded w-full font-mono text-sm">{src.txt}</pre>
				{/if}
			{/await}
		</div>
	</div>
</section>

<style>
	.card-width-default {
		width: calc(100% - 2rem);
	}
	@media (min-width: 768px) {
		.card-width-default {
			width: 60%;
		}
	}
	.img-box {
		min-height: 30vh;
	}
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
