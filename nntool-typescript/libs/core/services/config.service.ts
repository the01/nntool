/*******************************************************************************
 * Copyright 2019 alladin-IT GmbH
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 ******************************************************************************/

import { Injectable } from '@angular/core';
import { WebsiteSettings } from '../models/settings/settings.interface';
import { environment } from '@env/environment';

export interface MapSettingsResponse {
  mapfilter: {
    mapFilters: {
      // TODO: subclass deeper
      all: any[];
      wifi: any[];
      browser: any[];
      mobile: any[];
    };
    mapTypes: Array<{
      title: string;
      // TODO: subclass deeper
      options: any[];
    }>;
  };
}

export interface MapViewSettings {
  position: number[];
  zoom_initial: number;
  zoom_min: number;
  zoom_max: number;
  hybrid: {
    zoom_level: number;
  };
}

declare var __TEST_CONFIG__: any;

@Injectable()
export class ConfigService {
  private config: WebsiteSettings = environment;
  private constants: any = __TEST_CONFIG__;

  public clearArray(a: any[]): void {
    while (a.length > 0) {
      a.pop();
    }
  }

  public getConfig(): any {
    return environment;
  }

  public getVersion(): string {
    return this.constants.version ? this.constants.version : '';
  }

  public getBranch(): string {
    return this.constants.branch ? this.constants.branch : '';
  }

  public getRevision(): string {
    return this.constants.revision ? this.constants.revision : '';
  }

  public getClient(): string {
    return this.constants.client ? this.constants.client : '';
  }

  public getServerControl(): string {
    return this.config.servers.control;
  }

  public getServerStatistic(): string {
    return this.config.servers.statistic;
  }

  public getServerMap(): string {
    return this.config.servers.map;
  }

  public getBingKey(): string {
    return this.config.keys ? this.config.keys.google : '';
  }

  public getMapViewSettings(): MapViewSettings {
    return this.config.map ? this.config.map.view : null;
  }
}
