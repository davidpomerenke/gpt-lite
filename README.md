# GPT--, An Alternative ChatGPT UI

The GPT4 API is much cheaper than the ChatGPT subscription.[^1] This project provides a minimal UI to mimic the basic features of the ChatGPT subscription.

- [ ] The core feature is **storing and organizing conversations**, such that results can be retrieved easily, and old conversations can be continued.
- [x] Live **streaming** of replies is supported.
- [ ] ~~Other features of the ChatGPT subscription, namely **search and plugins**, are interesting but ultimately rather useless gimmicks, and I do not implement them.~~
- [ ] As an additional feature, this UI will allow **editing the system prompt** in a convenient manner, and storing and editing multiple bot personas.

[^1]: Access to the GPT4 API requires a special application and is not publicly available. This project will therefore be most useful for AI engineeres/researchers/students.

## Usage

1. `npm install`
2. `npm start`

## Development

Server and client parts should be run in separate processes, such that both can be hot-reloaded:

- `npm run server`
- `npm run client`

## License

MIT license (c) David Pomerenke 2023
