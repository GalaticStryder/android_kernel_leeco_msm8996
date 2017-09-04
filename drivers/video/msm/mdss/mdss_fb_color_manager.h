/* Copyright (c) 2008-2016, The Linux Foundation. All rights reserved.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 2 and
 * only version 2 as published by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 */

#ifndef MDSS_FB_COLOR_MANAGER_H
#define MDSS_FB_COLOR_MANAGER_H

#define DEFAULT_RGB_VALUE 32768

struct mdss_fb_color_manager_data {
	int red, green, blue;
	bool force_calibration;
};

int mdss_fb_color_manager_allocate(struct platform_device *pdev,
			struct mdss_dsi_ctrl_pdata *ctrl);
int mdss_fb_color_manager_params(struct device_node *np,
			struct mdss_dsi_ctrl_pdata *ctrl);
int mdss_fb_color_manager_calibration(struct mdss_dsi_ctrl_pdata *ctrl);

#endif /* MDSS_FB_COLOR_MANAGER_H */
