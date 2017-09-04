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

#include <linux/interrupt.h>
#include <linux/of.h>
#include <linux/of_platform.h>

#include "mdss_mdp.h"
#include "mdss_dsi.h"
#include "mdss_fb.h"

int mdss_fb_color_manager_allocate(struct platform_device *pdev,
		struct mdss_dsi_ctrl_pdata *ctrl)
{
	ctrl->color_mgr = devm_kzalloc(&pdev->dev,
		sizeof(struct mdss_fb_color_manager_data),
		GFP_KERNEL);
	if (!ctrl->color_mgr) {
		pr_err("%s: FAILED: Cannot allocate color_mgr node!\n", __func__);
		goto fail;
	};

	return 0;

fail:
	devm_kfree(&pdev->dev, ctrl->color_mgr);

	return -ENOMEM;
}

int mdss_fb_color_manager_params(struct device_node *np,
	struct mdss_dsi_ctrl_pdata *ctrl)
{
	int rc = 0;
	u32 tmp[3];
	struct mdss_fb_color_manager_data *color_mgr = ctrl->color_mgr;

	if (!of_find_property(np, "qcom,mdss-fb-color-manager", NULL))
		goto end;

	rc = of_property_read_u32_array(np,
		"qcom,mdss-fb-color-manager-value", tmp, 3);
	color_mgr->red = (!rc ? tmp[0] : DEFAULT_RGB_VALUE);
	color_mgr->green = (!rc ? tmp[1] : DEFAULT_RGB_VALUE);
	color_mgr->blue = (!rc ? tmp[2] : DEFAULT_RGB_VALUE);

	color_mgr->force_calibration = of_property_read_bool(np,
		"qcom,mdss-fb-color-manager-force");

end:
	return rc;
}

int mdss_fb_color_manager_calibration(struct mdss_dsi_ctrl_pdata *ctrl)
{
	int r, g, b;
	int ret;
	u32 copyback = 0;
	struct mdss_fb_color_manager_data *color_mgr = ctrl->color_mgr;
	struct mdss_data_type *mdata = mdss_mdp_get_mdata();
	struct msm_fb_data_type *mfd = mdata->ctl_off->mfd;
	struct mdp_pcc_cfg_data pcc_cfg;
	struct mdp_pcc_data_v1_7 pcc_data;

	r = color_mgr->red;
	g = color_mgr->green;
	b = color_mgr->blue;

	if (r < 0 || r > 32768)
		return -EINVAL;
	if (g < 0 || g > 32768)
		return -EINVAL;
	if (b < 0 || b > 32768)
		return -EINVAL;

	memset(&pcc_cfg, 0, sizeof(struct mdp_pcc_cfg_data));
	
	pcc_cfg.version = mdp_pcc_v1_7;
	pcc_cfg.block = MDP_LOGICAL_BLOCK_DISP_0;
	if (r == 32768 && g == 32768 && b == 32768)
		pcc_cfg.ops = MDP_PP_OPS_DISABLE;
	else
		pcc_cfg.ops = MDP_PP_OPS_ENABLE;
	pcc_cfg.ops |= MDP_PP_OPS_WRITE;
	pcc_cfg.r.r = r;
	pcc_cfg.g.g = g;
	pcc_cfg.b.b = b;
	
	memset(&pcc_data, 0, sizeof(struct mdp_pcc_data_v1_7));
	
	pcc_data.r.r = pcc_cfg.r.r;
	pcc_data.g.g = pcc_cfg.g.g;
	pcc_data.b.b = pcc_cfg.b.b;
	pcc_cfg.cfg_payload = &pcc_data;

	ret = mdss_mdp_pcc_config(mfd, &pcc_cfg, &copyback);
	if (ret != 0)
		return ret;

	return 0;
}
