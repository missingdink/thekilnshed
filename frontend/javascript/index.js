import "$styles/index.css";

import { Application } from "@hotwired/stimulus";
import NavController from "./controllers/nav_controller";
import ContactFormController from "./controllers/contact_form_controller";
import AnnouncementController from "./controllers/announcement_controller";

const application = Application.start();

// Register Stimulus controllers in frontend/javascript/controllers/
application.register("nav", NavController);
application.register("contact-form", ContactFormController);
application.register("announcement", AnnouncementController);
