# Todo App Frontend

Frontend React pour l'application Todo App déployée sur AWS.

## Configuration de l'URL de l'API

L'application utilise une variable d'environnement pour configurer l'URL du backend API.

### Méthode 1: Fichier .env (Recommandé)

Créez un fichier `.env` à la racine du dossier `frontend` avec le contenu suivant:

```env
REACT_APP_API_URL=http://votre-serveur-api.com:3000
```

**Exemples:**
- Pour le développement local: `REACT_APP_API_URL=http://localhost:3000`
- Pour un serveur distant: `REACT_APP_API_URL=http://192.168.1.100:3000`
- Pour un serveur AWS: `REACT_APP_API_URL=http://ec2-xxx-xxx-xxx.compute.amazonaws.com:3000`

### Méthode 2: Variable d'environnement système

Vous pouvez aussi définir la variable avant de lancer l'application:

```bash
REACT_APP_API_URL=http://votre-serveur.com:3000 npm start
```

### Méthode 3: Override dynamique (développement)

Dans la console du navigateur, vous pouvez définir:

```javascript
window.REACT_APP_API_URL = 'http://votre-serveur.com:3000';
```

Puis rechargez la page.

**Note:** Après avoir modifié le fichier `.env`, vous devez redémarrer le serveur de développement (`npm start`).

---

# Getting Started with Create React App

This project was bootstrapped with [Create React App](https://github.com/facebook/create-react-app).

## Available Scripts

In the project directory, you can run:

### `npm start`

Runs the app in the development mode.\
Open [http://localhost:3000](http://localhost:3000) to view it in your browser.

The page will reload when you make changes.\
You may also see any lint errors in the console.

### `npm test`

Launches the test runner in the interactive watch mode.\
See the section about [running tests](https://facebook.github.io/create-react-app/docs/running-tests) for more information.

### `npm run build`

Builds the app for production to the `build` folder.\
It correctly bundles React in production mode and optimizes the build for the best performance.

The build is minified and the filenames include the hashes.\
Your app is ready to be deployed!

See the section about [deployment](https://facebook.github.io/create-react-app/docs/deployment) for more information.

### `npm run eject`

**Note: this is a one-way operation. Once you `eject`, you can't go back!**

If you aren't satisfied with the build tool and configuration choices, you can `eject` at any time. This command will remove the single build dependency from your project.

Instead, it will copy all the configuration files and the transitive dependencies (webpack, Babel, ESLint, etc) right into your project so you have full control over them. All of the commands except `eject` will still work, but they will point to the copied scripts so you can tweak them. At this point you're on your own.

You don't have to ever use `eject`. The curated feature set is suitable for small and middle deployments, and you shouldn't feel obligated to use this feature. However we understand that this tool wouldn't be useful if you couldn't customize it when you are ready for it.

## Learn More

You can learn more in the [Create React App documentation](https://facebook.github.io/create-react-app/docs/getting-started).

To learn React, check out the [React documentation](https://reactjs.org/).

### Code Splitting

This section has moved here: [https://facebook.github.io/create-react-app/docs/code-splitting](https://facebook.github.io/create-react-app/docs/code-splitting)

### Analyzing the Bundle Size

This section has moved here: [https://facebook.github.io/create-react-app/docs/analyzing-the-bundle-size](https://facebook.github.io/create-react-app/docs/analyzing-the-bundle-size)

### Making a Progressive Web App

This section has moved here: [https://facebook.github.io/create-react-app/docs/making-a-progressive-web-app](https://facebook.github.io/create-react-app/docs/making-a-progressive-web-app)

### Advanced Configuration

This section has moved here: [https://facebook.github.io/create-react-app/docs/advanced-configuration](https://facebook.github.io/create-react-app/docs/advanced-configuration)

### Deployment

This section has moved here: [https://facebook.github.io/create-react-app/docs/deployment](https://facebook.github.io/create-react-app/docs/deployment)

### `npm run build` fails to minify

This section has moved here: [https://facebook.github.io/create-react-app/docs/troubleshooting#npm-run-build-fails-to-minify](https://facebook.github.io/create-react-app/docs/troubleshooting#npm-run-build-fails-to-minify)
