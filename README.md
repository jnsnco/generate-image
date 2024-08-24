A basic script that allows anyone to generate images using AI, via command line, with an API key. Works on MacOS, should also work on any Linux distro or any other system with Bash. No dependencies. Perfect for sharing one account with a team. The API key is read from a separate file, which could stored on a shared drive.

Currently supports only OpenAI DALL·E.

Saves the image file to a configurable directory, along with a json file that contains the original prompt, the AI revised prompt, and additional info. Both filenames contain the same timestamp for reference purposes. 

To run it, use the following command:

```
bash gen-image.sh
```
